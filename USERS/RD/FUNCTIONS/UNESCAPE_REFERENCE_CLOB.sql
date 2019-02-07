CREATE OR REPLACE
FUNCTION UNESCAPE_REFERENCE_CLOB(gCLOB IN CLOB)
RETURN CLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    nLoops PLS_INTEGER := 0;
    lVarChar VARCHAR2(32767 BYTE) := NULL;
    lCLOB CLOB := EMPTY_CLOB();
    
BEGIN
    
    nLoops := FLOOR((DBMS_LOB.GetLength(gCLOB))/1000);
    
    DBMS_LOB.CreateTemporary(lCLOB, TRUE);
    
    
    FOR i IN 0..nLoops LOOP
        
        lVarChar := UTL_I18N.UNESCAPE_REFERENCE(DBMS_LOB.Substr(gCLOB, 1000, 1 + (1000*i)));
        
        DBMS_LOB.WriteAppend(lCLOB, LENGTH(lVarChar), lVarChar);
        
    END LOOP;
    
    
    RETURN lCLOB;
    
END;
/