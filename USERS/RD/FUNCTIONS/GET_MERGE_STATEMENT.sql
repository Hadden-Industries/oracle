--DROP FUNCTION GET_MERGE_STATEMENT;

/*- - - - --

Function to return a merge statement for a specified table.
The logic for the delta set may also be input to enable the output of this function to be run programatically e.g. EXECUTE IMMEDIATE(GET_MERGE_STATEMENT(...));
Optionally, a unique constraint on the table may be specified.
Changes can be compared via a MINUS statement or on a row-by-row basis using ROW

If no constraint name to be used in matching is given, then all possible constraints will be enumerated. The primary key will be preferred, then all other unique constraints.

-- - - - -*/

CREATE OR REPLACE
FUNCTION GET_MERGE_STATEMENT
(
    gTableName IN VARCHAR2,
    gDelta IN CLOB DEFAULT NULL,
    gConstraintName IN VARCHAR2 DEFAULT NULL,
    gComparison IN VARCHAR2 DEFAULT 'MINUS'
)
RETURN CLOB
AUTHID CURRENT_USER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    vTableName VARCHAR2(30 BYTE) := '';
    vConstraintName VARCHAR2(30 BYTE) := '';
    vBuffer VARCHAR2(32767 BYTE) := '';
    cOutput CLOB := EMPTY_CLOB();
    
BEGIN
    
    --Check that the table exists
    BEGIN
        
        SELECT Table_Name
        INTO vTableName
        FROM USER_TABLES
        WHERE Table_Name = ORACLE_NAME(gTableName);
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        RETURN NULL;
        
    END;
    
    --If specified constraint name explicitly
    IF gConstraintName IS NOT NULL THEN
    
        --Check if the constraint exists
        BEGIN
            
            SELECT Constraint_Name
            INTO vConstraintName
            FROM USER_CONSTRAINTS
            WHERE Table_Name = vTableName
            AND Constraint_Name = ORACLE_NAME(gConstraintName);
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            RETURN NULL;
            
        END;
    
    END IF;
       
    
    DBMS_LOB.CreateTemporary
    (
        cOutput,
        TRUE,
        DBMS_LOB.SESSION
    );
    
    cOutput := 'MERGE
INTO ' || vTableName || ' X
USING
(
    ' || gDelta;
    
    IF gComparison = 'MINUS' THEN
        
        vBuffer := '-' || '-' || '
    MINUS
    -' || '-' || '
    SELECT ' || DBMS_LOB.Substr(GET_COLUMN_LIST(vTableName, '    '), 32767, 5) || '
    FROM ' || vTableName;
        
        DBMS_LOB.WriteAppend
        (
            lob_loc=>cOutput,
            amount=>LENGTH(vBuffer),
            buffer=>vBuffer
        ); 
        
    END IF;

cOutput := cOutput || '
) Y';


FOR C IN
(
    SELECT Constraint_Name,
    ROW_NUMBER() OVER (ORDER BY Constraint_Type, Constraint_Name) AS RN,
    COUNT(*) OVER () AS Cnt
    FROM USER_CONSTRAINTS
    WHERE Table_Name = vTableName
    AND Constraint_Name = COALESCE(gConstraintName, Constraint_Name)
    AND Constraint_Type IN ('P', 'U')
    AND Status = 'ENABLED'
    AND Validated = 'VALIDATED'
    AND Bad IS NULL
    AND Invalid IS NULL
    ORDER BY Constraint_Type,
    Constraint_Name
) LOOP
    
    vBuffer := CASE
        WHEN C.RN = 1 THEN '
    ON ('
        ELSE '
-' || '-    ON ('
    END;
    
    DBMS_LOB.WriteAppend
    (
        lob_loc=>cOutput,
        amount=>LENGTH(vBuffer),
        buffer=>vBuffer
    );
    
    FOR D IN
    (
        SELECT CASE
            WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
            ELSE B.Comments
        END AS Column_Name,
        A.Position,
        COUNT(*) OVER () AS Cnt
        FROM USER_CONS_COLUMNS A
        LEFT OUTER JOIN USER_COL_COMMENTS B
        ON A.Table_Name = B.Table_Name
                AND A.Column_Name = B.Column_Name
        WHERE A.Constraint_Name = C.Constraint_Name
        ORDER BY A.Position
    ) LOOP
        
        vBuffer := CASE
            WHEN D.Position = 1 THEN NULL
            ELSE CASE
                WHEN C.RN = 1 THEN '
    '
                ELSE '
-' || '-    '
            END || '        AND '
        END || 'X.' || D.Column_Name || ' = Y.' || D.Column_Name || CASE
        WHEN D.Position = D.Cnt THEN ')'
        ELSE NULL
        END;
        
        DBMS_LOB.WriteAppend
        (
            lob_loc=>cOutput,
            amount=>LENGTH(vBuffer),
            buffer=>vBuffer
        );
    
    END LOOP;
    

END LOOP;


cOutput := cOutput || '
WHEN MATCHED THEN UPDATE SET ';
    
    FOR E IN
    (
        SELECT ROW_NUMBER() OVER (ORDER BY A.Column_ID) AS RN,
        COUNT(*) OVER () AS Cnt,
        CASE
            WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
            ELSE B.Comments
        END AS Column_Name
        FROM USER_TAB_COLS A
        LEFT OUTER JOIN USER_COL_COMMENTS B
        ON A.Table_Name = B.Table_Name
                AND A.Column_Name = B.Column_Name
        WHERE A.Table_Name = vTableName
        AND A.Hidden_Column = 'NO'
        AND A.Virtual_Column = 'NO'
        --Do not include the default-joined column(s)
        AND A.Column_Name NOT IN
        (
            SELECT Column_Name
            FROM USER_CONS_COLUMNS
            WHERE Constraint_Name =
            (
                SELECT Constraint_Name
                FROM
                (
                    SELECT Constraint_Name,
                    ROW_NUMBER() OVER (ORDER BY Constraint_Type, Constraint_Name) AS RN
                    FROM USER_CONSTRAINTS
                    WHERE Table_Name = vTableName
                    AND Constraint_Name = COALESCE(gConstraintName, Constraint_Name)
                    AND Constraint_Type IN ('P', 'U')
                    AND Status = 'ENABLED'
                    AND Validated = 'VALIDATED'
                    AND Bad IS NULL
                    AND Invalid IS NULL
                )
                WHERE RN = 1
            )
        )
        ORDER BY A.Column_ID
    ) LOOP
        
        vBuffer := 'X.' || E.Column_Name || ' = Y.' || E.Column_Name || CASE
            WHEN E.RN <> E.Cnt THEN ',
'
            ELSE NULL
        END;
        
        DBMS_LOB.WriteAppend
        (
            lob_loc=>cOutput,
            amount=>LENGTH(vBuffer),
            buffer=>vBuffer
        ); 
        
    END LOOP;
    
    IF gComparison = 'ROW' THEN
        
        FOR E IN
        (
            SELECT ROW_NUMBER() OVER (ORDER BY Column_ID) AS RN,
            COUNT(*) OVER () AS Cnt,
            Data_Type,
            Column_Name AS Orig$Column_Name,
            CASE
                WHEN Nullable = 'Y' THEN 'COALESCE(X.' || Column_Name || CASE
                    WHEN Data_Type = 'DATE' THEN ', TO_DATE(''00010101'', ''YYYYMMDD'')'
                    WHEN Data_Type = 'NUMBER' THEN ',-1'
                    ELSE ',''-1'''
                    END || ')'
                ELSE 'X.' || Column_Name
            END AS COALESCE_Statement
            FROM
            (
                SELECT A.Column_ID,
                A.Nullable,
                A.Data_Type,
                CASE
                    WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
                    ELSE B.Comments
                END AS Column_Name
                FROM USER_TAB_COLS A
                LEFT OUTER JOIN USER_COL_COMMENTS B
                ON A.Table_Name = B.Table_Name
                        AND A.Column_Name = B.Column_Name
                WHERE A.Table_Name = vTableName
                AND A.Hidden_Column = 'NO'
                AND A.Virtual_Column = 'NO'
                --Do not include the default-joined column(s)
                AND A.Column_Name NOT IN
                (
                    SELECT Column_Name
                    FROM USER_CONS_COLUMNS
                    WHERE Constraint_Name =
                    (
                        SELECT Constraint_Name
                        FROM
                        (
                            SELECT Constraint_Name,
                            ROW_NUMBER() OVER (ORDER BY Constraint_Type, Constraint_Name) AS RN
                            FROM USER_CONSTRAINTS
                            WHERE Table_Name = vTableName
                            AND Constraint_Name = COALESCE(gConstraintName, Constraint_Name)
                            AND Constraint_Type IN ('P', 'U')
                            AND Status = 'ENABLED'
                            AND Validated = 'VALIDATED'
                            AND Bad IS NULL
                            AND Invalid IS NULL
                        )
                        WHERE RN = 1
                    )
                )
            )
            ORDER BY Column_ID
        ) LOOP
            
            vBuffer := CASE
                WHEN E.RN = 1 THEN '
WHERE '
                ELSE 'OR '
            END
            || CASE
                WHEN E.Data_Type <> 'SDO_GEOMETRY' THEN E.COALESCE_Statement || ' <> ' || REPLACE(E.COALESCE_Statement, 'X.', 'Y.')
                ELSE 'CASE
    WHEN X.' || E.Orig$Column_Name || ' IS NULL AND Y.' || E.Orig$Column_Name || ' IS NOT NULL THEN -3
    WHEN X.' || E.Orig$Column_Name || ' IS NOT NULL AND Y.' || E.Orig$Column_Name || ' IS NULL THEN -2
    WHEN X.' || E.Orig$Column_Name || ' IS NULL AND Y.' || E.Orig$Column_Name || ' IS NULL THEN 0
    ELSE DBMS_LOB.Compare(SDO_UTIL.To_KMLGeometry(X.' || E.Orig$Column_Name || '), SDO_UTIL.To_KMLGeometry(Y.' || E.Orig$Column_Name || '))
END <> 0'
            END
            || CASE
                WHEN E.RN <> E.Cnt THEN '
'
                ELSE NULL
            END;
            
            DBMS_LOB.WriteAppend
            (
                lob_loc=>cOutput,
                amount=>LENGTH(vBuffer),
                buffer=>vBuffer
            ); 
            
        END LOOP;
        
    END IF;
    
    cOutput := cOutput || '
WHEN NOT MATCHED THEN INSERT
(
';
    
    
    FOR F IN
    (
        SELECT Column_ID,
        Column_Name,
        ROW_NUMBER() OVER(ORDER BY Column_ID) AS RN,
        COUNT(*) OVER () AS Cnt
        FROM USER_TAB_COLS
        WHERE Table_Name = vTableName
        AND Hidden_Column = 'NO'
        AND Virtual_Column = 'NO'
        ORDER BY Column_ID
    ) LOOP
        
        vBuffer := '    ' || F.Column_Name || CASE
            WHEN F.RN <> F.Cnt THEN ',
'
            ELSE NULL
        END;
        
        DBMS_LOB.WriteAppend
        (
            lob_loc=>cOutput,
            amount=>LENGTH(vBuffer),
            buffer=>vBuffer
        ); 
        
    END LOOP;
    
    
    cOutput := cOutput || '
)
VALUES
(
';
    
    
    FOR G IN
    (
        SELECT A.Column_ID,
        CASE
            WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
            ELSE B.Comments
        END AS Column_Name,
        ROW_NUMBER() OVER(ORDER BY Column_ID) AS RN,
        COUNT(*) OVER () AS Cnt
        FROM USER_TAB_COLS A
        LEFT OUTER JOIN USER_COL_COMMENTS B
        ON A.Table_Name = B.Table_Name
                AND A.Column_Name = B.Column_Name
        WHERE A.Table_Name = vTableName
        AND A.Hidden_Column = 'NO'
        AND A.Virtual_Column = 'NO'
        ORDER BY A.Column_ID
    ) LOOP
        
        vBuffer := '    ' || 'Y.' || G.Column_Name || CASE
            WHEN G.RN <> G.Cnt THEN ',
'
            ELSE NULL
        END;
        
        DBMS_LOB.WriteAppend
        (
            lob_loc=>cOutput,
            amount=>LENGTH(vBuffer),
            buffer=>vBuffer
        ); 
        
    END LOOP;
    
    
    cOutput := cOutput || '
)';
    
    RETURN cOutput;

END;
/

/*
--test
SELECT GET_MERGE_STATEMENT
(
    'country',
    NULL,
    NULL,
    'ROW'
)
FROM DUAL;

SELECT GET_MERGE_STATEMENT
(
    gTableName=>'FXRATE',
    gComparison=>'ROW'
)
FROM DUAL;
*/