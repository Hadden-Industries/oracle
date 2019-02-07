SET SERVEROUTPUT ON;

CREATE OR REPLACE
FUNCTION TABLE_TO_JSON(gTable_Name IN VARCHAR2)
RETURN CLOB
PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    j JSON_OBJECT_T := JSON_OBJECT_T();
    jCol JSON_OBJECT_T := JSON_OBJECT_T();
    jCols JSON_ARRAY_T := JSON_ARRAY_T();
    
    vTable_Name VARCHAR2(30 BYTE) := ORACLE_NAME(gTable_Name);
    vTable_Description VARCHAR2(4000 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.Enable;
    
    FOR C IN
    (
        SELECT A.Column_Name AS Name,
        A.Column_ID - 1 AS Column_ID,
        CASE A.Data_Type
            WHEN 'DATE' THEN 'DATETIME'
            WHEN 'NUMBER' THEN 'NUMBER'
            WHEN 'SDO_GEOMETRY' THEN 'LOCATION'
            ELSE 'STRING'
        END AS Type,
        B.Comments AS Description
        FROM USER_TAB_COLS A
        LEFT OUTER JOIN USER_COL_COMMENTS B
            ON A.Table_Name = B.Table_Name
                    AND A.Column_Name = B.Column_Name
        WHERE A.Table_Name = vTable_Name
        AND A.Hidden_Column = 'NO'
        ORDER BY A.Column_ID
    ) LOOP
        
        jCol.put('columnId', C.Column_ID);
        --jCol.put('description', C.Description);
        jCol.put('name', C.Name);
        jCol.put('type', C.Type);
        
        jCols.append(jCol);
        
    END LOOP;
    
    j.put('columns', jCols);
    j.put('isExportable', true);
    j.put('name', vTable_Name);
    
    BEGIN
        
        SELECT Description
        INTO vTable_Description
        FROM TABLELOOKUP
        WHERE Name = vTable_Name;
        
        j.put('description', vTable_Description);
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    RETURN j.to_CLOB;
    
END;
/

/*
SET SERVEROUTPUT ON;

DECLARE
    
    j CLOB := EMPTY_CLOB();
    cCLOB CLOB := EMPTY_CLOB();
    
BEGIN
    
    j := TABLE_TO_JSON('UNLOCODE');
    
    DBMS_LOB.CreateTemporary(cCLOB, true);
    
    cCLOB := j;
    
    DBMS_OUTPUT.Put_Line(cCLOB);
    
    DBMS_OUTPUT.Put_Line('Length:' || DBMS_LOB.GetLength(cCLOB));
    
END;
/
*/