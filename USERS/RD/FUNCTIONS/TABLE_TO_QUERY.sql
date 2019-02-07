CREATE OR REPLACE
FUNCTION TABLE_TO_QUERY
(
    gTable_Name IN VARCHAR2,
    gFilter IN VARCHAR2 DEFAULT NULL
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vColumnList VARCHAR2(4000 BYTE) := '';
    vOrder VARCHAR2(4000 BYTE) := '';
    vTable_Name VARCHAR2(30 BYTE) := ORACLE_NAME(gTable_Name);
    
BEGIN
    
    BEGIN
        
        SELECT Table_Name
        INTO vTable_Name
        FROM USER_TABLES
        WHERE Table_Name = vTable_Name;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        RETURN NULL;
        
    END;
    
    --Hack to escape connect-by loops in the data
    IF vTable_Name = 'LANGUAGE' THEN
        
        RETURN 'SELECT * FROM LANGUAGE ORDER BY ID';
        
    END IF;
    
    
    FOR C IN
    (
        SELECT A.Column_ID,
        A.Data_Type,
        CASE
            WHEN A.Data_Type = 'DATE' THEN 'TO_CHAR(' || A.Column_Name || ', ''' || CASE
                WHEN A.Column_Name LIKE 'DATETIME%' THEN 'YYYY-MM-DD"T"HH24:MI:SS'
                ELSE 'YYYY-MM-DD'
            END || ''') AS ' || A.Column_Name
            WHEN A.Data_Type = 'SDO_GEOMETRY' THEN 'CASE
    WHEN ' || A.Column_Name || ' IS NOT NULL THEN CASE
        WHEN DBMS_LOB.GetLength(SDO_UTIL.To_KMLGeometry(' || A.Column_Name || ')) < 1000000 THEN SDO_UTIL.To_KMLGeometry(' || A.Column_Name || ')
        ELSE SDO_UTIL.To_KMLGeometry(SDO_UTIL.Simplify(SDO_UTIL.Rectify_Geometry(' || A.Column_Name || ', 0.05), 2500, 0.05))
    END
    ELSE NULL
END AS ' || A.Column_Name
            WHEN A.Data_Type LIKE 'TIMESTAMP%' THEN 'TO_CHAR(' || A.Column_Name || ', ''' || 'YYYY-MM-DD"T"HH24:MI:SS' || ''') AS ' || A.Column_Name
            WHEN A.Data_Type = 'RAW' AND A.Data_Length = 16 AND A.Column_Name = 'UUID'  THEN 'CANONICALISE_UUID(UUID) AS UUID'
            ELSE A.Column_Name
        END AS Column_Name,
        COUNT(*) OVER () AS Cnt
        FROM USER_TAB_COLS A
        WHERE A.Table_Name = vTable_Name
        AND A.Hidden_Column = 'NO'
        ORDER BY A.Column_ID
    ) LOOP
        
        vColumnList := vColumnList
        || C.Column_Name
        || CASE
            WHEN C.Column_ID <> C.Cnt THEN ','
            ELSE NULL
        END
        || CHR(10);
        
    END LOOP;
    
    
    BEGIN
        
        SELECT S1 || CHR(10) || S2 AS vOrder
        INTO vOrder
        FROM
        (
            SELECT LISTAGG(S1, CHR(10)) WITHIN GROUP (ORDER BY Position) AS S1,
            LISTAGG(S2, CHR(10)) WITHIN GROUP (ORDER BY Position) AS S2
            FROM
            (
                SELECT Position,
                CASE
                    WHEN Column_Name <> Prior$Column_Name THEN CASE Position - ColumnSameCount
                        WHEN 1 THEN 'START WITH ' || Column_Name || ' IS NULL'
                        ELSE 'AND ' || Column_Name || ' IS NULL'
                    END
                    ELSE NULL
                END AS S1,
                CASE Position
                    WHEN 1 THEN 'CONNECT BY ' || Column_Name ||  ' = PRIOR ' || Prior$Column_Name
                    ELSE 'AND ' || Column_Name || ' = PRIOR ' || Prior$Column_Name
                END AS S2
                FROM
                (
                    SELECT C.Position,
                    C.Column_Name,
                    D.Column_Name AS Prior$Column_Name,
                    SUM
                    (
                        CASE
                            WHEN C.Column_Name = D.Column_Name THEN 1
                            ELSE 0
                        END
                    ) OVER () AS ColumnSameCount
                    FROM USER_CONSTRAINTS A
                    INNER JOIN USER_CONSTRAINTS B
                        ON A.Table_Name = B.Table_Name
                                AND A.R_Constraint_Name = B.Constraint_Name
                    INNER JOIN USER_CONS_COLUMNS C
                        ON A.Table_Name = C.Table_Name
                                AND A.Constraint_Name = C.Constraint_Name
                    INNER JOIN USER_CONS_COLUMNS D
                        ON B.Table_Name = D.Table_Name
                                AND B.Constraint_Name = D.Constraint_Name
                                AND C.Position = D.Position
                    WHERE A.Table_Name = vTable_Name
                    AND A.Constraint_Type = 'R'
                    AND B.Constraint_Type = 'P'
                )
            )
        )
        WHERE S1 IS NOT NULL
        AND S2 IS NOT NULL;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        SELECT 'ORDER BY ' || COALESCE(vOrder, '1') AS vOrder
        INTO vOrder
        FROM
        (
            SELECT LISTAGG(Column_Name, ',') WITHIN GROUP (ORDER BY Position) AS vOrder
            FROM USER_CONS_COLUMNS
            WHERE (Table_Name, Constraint_Name) IN
            (
                SELECT Table_Name,
                Constraint_Name
                FROM
                (
                    SELECT Table_Name,
                    Constraint_Name,
                    ROW_NUMBER() OVER (ORDER BY Constraint_Type, Constraint_Name) AS RN
                    FROM USER_CONSTRAINTS
                    WHERE vTable_Name = Table_Name
                    AND Constraint_Type IN
                    (
                        'P', --Primary
                        'U' --Unique
                    )
                )
                WHERE RN = 1
            )
        );
        
    END;
    
    /*
    Hierarchy code will not work with geometry directly:
    "ORA-22813: operand value exceeds system limits
    22813. 00000 -  "operand value exceeds system limits"
    *Cause:    Object or Collection value was too large. The size of the value
               might have exceeded 30k in a SORT context, or the size might be
               too big for available memory.
    *Action:   Choose another value and retry the operation."
    but will with the KML CLOB in an outer statement
    */
    RETURN CASE
        WHEN vOrder NOT LIKE 'START WITH%' THEN NULL
        ELSE 'SELECT *
FROM
(
'
    END
    || 'SELECT ' || vColumnList
    || 'FROM ' || vTable_Name
    || CASE
        WHEN gFilter IS NULL THEN NULL
        ELSE CHR(10) || gFilter
    END
    || CHR(10) || CASE
        WHEN vOrder NOT LIKE 'START WITH%' THEN NULL
        ELSE ')
'
    END
    || vOrder;
    
END;
/

/*
--test
SELECT TABLE_TO_QUERY('COMPANYREGISTER')
FROM DUAL;

--test invalid table name
SELECT TABLE_TO_QUERY('NO_SUCH_TABLE')
FROM DUAL;

--Hierarchy too complex with geometry
SELECT ID,
PARENT$GBRONSGEOGCODE_ID,
GBRONSRGC_ID,
GBRSTATUTORYINSTRUMENT_ID,
TO_CHAR(DATESTART, 'YYYY-MM-DD') AS DATESTART,
CYM$NAME,
SDO_UTIL.To_KMLGeometry(GEOMETRY) AS GEOMETRY,
NAME
FROM GBRONSGEOGCODE
START WITH PARENT$GBRONSGEOGCODE_ID IS NULL
CONNECT BY PARENT$GBRONSGEOGCODE_ID = PRIOR ID;

--test with filter
SELECT TABLE_TO_QUERY('GEONAMES', 'WHERE Country_ID = ''CYP'' AND CountrySubdiv_Code = ''02''')
FROM DUAL;

SELECT TABLE_TO_QUERY('GEONAMES', 'WHERE ID IN (SELECT GeoNames_ID FROM MARKET)')
FROM DUAL;

--two column hierarchies
SELECT *
FROM COUNTRYSUBDIV
START WITH PARENT$COUNTRYSUBDIV_CODE IS NULL
CONNECT BY COUNTRY_ID = PRIOR COUNTRY_ID
AND PARENT$COUNTRYSUBDIV_CODE = PRIOR CODE;

--?
SELECT *
FROM CHD
START WITH PARENT$CHD_ID IS NULL
AND PARENT$CHD_DATESTART IS NULL
CONNECT BY PARENT$CHD_ID = PRIOR ID
AND PARENT$CHD_DATESTART = PRIOR DATESTART;

--one column hierarchy
SELECT *
FROM MARKET
START WITH PARENT$MARKET_ID IS NULL
CONNECT BY PARENT$MARKET_ID = PRIOR ID;

--no hierarchy
SELECT *
FROM DBMS
ORDER BY ID;

--Inconsistent hierarchies
SET SERVEROUTPUT ON;

DECLARE

    nNULLs PLS_INTEGER := 0;

BEGIN
    
    DBMS_OUTPUT.Enable;
    
    FOR C IN
    (
        SELECT Table_Name,
        Column_Name
        FROM USER_TAB_COLS
        WHERE Column_Name LIKE 'PARENT$%'
    ) LOOP
        
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || C.Table_Name || ' WHERE :1 IS NULL'
        INTO nNULLs
        USING C.Column_Name;
        
        IF nNULLs <> 0 THEN
            
            DBMS_OUTPUT.Put_Line(C.Table_Name);
            
        END IF;
        
    END LOOP;
    
END;
/
*/