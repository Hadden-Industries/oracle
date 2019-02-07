--DROP FUNCTION GET_COLUMN_LIST;

CREATE OR REPLACE
FUNCTION GET_COLUMN_LIST
(
    gTableName IN VARCHAR2,
    gPrefix IN VARCHAR2 DEFAULT NULL
)
RETURN CLOB
AUTHID CURRENT_USER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    cList CLOB;
    
BEGIN
    
    DBMS_LOB.CreateTemporary
    (
        cList,
        TRUE,
        DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open(cList, DBMS_LOB.LOB_ReadWrite);
    
    FOR C IN
    (
        SELECT CASE
            WHEN gPrefix IS NOT NULL THEN gPrefix
            ELSE NULL
        END
        || MedialCapital$Column_Name
        || CASE
            WHEN Column_ID != Max$Column_ID THEN ',' || CHR(10)
            ELSE NULL
        END AS Text
        FROM
        (
            SELECT A.Column_ID,
            A.Column_Name,
            COALESCE
            (
                CASE
                    WHEN INSTRB(B.Comments, CHR(10)) > 0 THEN SUBSTRB(B.Comments, 1, INSTRB(B.Comments, CHR(10)) - 1)
                    ELSE B.Comments
                END,
                A.Column_Name
            ) AS MedialCapital$Column_Name,
            MAX(A.Column_ID) OVER (PARTITION BY A.Table_Name) AS Max$Column_ID
            FROM USER_TAB_COLS A
            LEFT OUTER JOIN USER_COL_COMMENTS B
                ON A.Table_Name = B.Table_Name
                        AND A.Column_Name = B.Column_Name
            WHERE A.Table_Name = ORACLE_NAME(gTableName)
            AND A.Hidden_Column = 'NO'
            AND A.Virtual_Column = 'NO'
        )
        ORDER BY Column_ID
    ) LOOP
        
        DBMS_LOB.WriteAppend
        (
            lob_loc => cList,
            amount => LENGTH(C.Text),
            buffer => C.Text
        );
        
    END LOOP;
    
    RETURN cList;
    
END;
/

/*
--test
SELECT RD.GET_COLUMN_LIST('COUNTRY')
FROM DUAL;
*/