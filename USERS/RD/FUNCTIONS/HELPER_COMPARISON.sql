CREATE OR REPLACE
FUNCTION HELPER_COMPARISON
(
    gTableName IN VARCHAR2,
    gConstraintName IN VARCHAR DEFAULT NULL
)
RETURN CLOB
AS
    
    cCLOB CLOB := EMPTY_CLOB;
    
BEGIN
    
    FOR C IN
    (
        WITH JOIN_COLUMN AS
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
                    WHERE Table_Name = gTableName
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
        --
        SELECT RN,
        JoinColumn,
        'IF ' || COALESCE_Statement || ' THEN' || CHR(10)
        || '    ' || CHR(10)
        || '    vMsg := vMsg || CHR(10)
    ||  ''<tr>''
    || ''<td>'' || TO_CHAR(SYSDATE, vTimeStampFormat) || ''</td>''
    || ''<td>'' || ''UPDATE'' || ''</td>''
    || ''<td>'' || ''' || Table_Name || '.' || Column_Name || ''' || ''</td>''
    || ''<td>'' || C.ID || ''</td>'';
    
    UPDATE
    ' || Table_Name || '
    SET ' || Column_Name || ' = C.' || Column_Name || '
    WHERE ID = C.ID;
    
    nUpdated := nUpdated + SQL%ROWCOUNT;
    
    vMsg := vMsg || ''<td>'' || '' ('' || ' || CASE
        WHEN Data_Type = 'SDO_GEOMETRY' THEN '''Geometry is different'''
        ELSE 'D.' || Column_Name || ' || ''=>'' || C.' || Column_Name
    END || ' || '')'' || ''</td>''
    || ''</tr>'';
    
END IF;' AS Stmnt
        FROM
        (
            SELECT Table_Name,
            Column_Name,
            Data_Type,
            JoinColumn,
            RN,
            Cnt,
            CASE
            WHEN Data_Type <> 'SDO_GEOMETRY' THEN COALESCE_Statement || ' <> ' || REPLACE(COALESCE_Statement, 'C.', 'D.')
            ELSE 'CASE
    WHEN C.' || Column_Name || ' IS NULL AND D.' || Column_Name || ' IS NOT NULL THEN -3
    WHEN C.' || Column_Name || ' IS NOT NULL AND D.' || Column_Name || ' IS NULL THEN -2
    WHEN C.' || Column_Name || ' IS NULL AND D.' || Column_Name || ' IS NULL THEN 0
    ELSE DBMS_LOB.Compare
    (
        SDO_UTIL.To_KMLGeometry(C.' || Column_Name || '),
        SDO_UTIL.To_KMLGeometry(D.' || Column_Name || ')
    )
    END <> 0'
            END AS COALESCE_Statement
            FROM
            (
                SELECT Table_Name,
                Column_ID,
                ROW_NUMBER() OVER (ORDER BY Column_ID) AS RN,
                COUNT(*) OVER () AS Cnt,
                Data_Type,
                Column_Name,
                JoinColumn,
                CASE
                    WHEN Nullable = 'Y' THEN 'COALESCE(C.' || Column_Name || CASE
                        WHEN Data_Type = 'DATE' THEN ', TO_DATE(''00010101'', ''YYYYMMDD'')'
                        WHEN Data_Type = 'NUMBER' THEN ', -1'
                        ELSE ', CHR(0)'
                        END || ')'
                    ELSE 'C.' || Column_Name
                END AS COALESCE_Statement
                FROM
                (
                    SELECT A.Table_Name,
                    A.Column_ID,
                    A.Nullable,
                    A.Data_Type,
                    CASE
                        WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
                        ELSE B.Comments
                    END AS Column_Name,
                    CASE
                        WHEN C.Column_Name IS NOT NULL THEN 1
                        ELSE 0
                    END AS JoinColumn
                    FROM USER_TAB_COLS A
                    LEFT OUTER JOIN USER_COL_COMMENTS B
                    ON A.Table_Name = B.Table_Name
                            AND A.Column_Name = B.Column_Name
                    LEFT OUTER JOIN JOIN_COLUMN C
                        ON A.Column_Name = C.Column_Name
                    WHERE A.Table_Name = gTableName
                    AND A.Hidden_Column = 'NO'
                    AND A.Virtual_Column = 'NO'
                )
            )
        )
        ORDER BY RN
    ) LOOP
        
        IF C.JoinColumn = 0 THEN
            
            IF C.RN = 1 THEN
                
                cCLOB := C.Stmnt;
                
            ELSE
                
                cCLOB := cCLOB || CHR(10)
                || CHR(10)
                || CHR(10) || C.Stmnt;
                
            END IF;
            
        END IF;
        
    END LOOP;
    
    RETURN cCLOB;

END;
/

/*
--test
SELECT HELPER_COMPARISON('GBRMETOFFICELOCATION')
FROM DUAL;
*/