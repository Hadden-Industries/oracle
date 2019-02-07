CREATE OR REPLACE
FUNCTION CLOB_IN_HEX_TO_VARCHAR2(gCLOB IN CLOB)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vReturn VARCHAR2(4000 BYTE) := '';
    nLength SIMPLE_INTEGER := COALESCE
    (
        DBMS_LOB.GetLength(gCLOB),
        0
    );
    nCurrentPlace SIMPLE_INTEGER := 1;
    -- these pieces will make up the entire CLOB
    vPiece VARCHAR2(2000 BYTE) := NULL;
    
BEGIN
    
    IF nLength = 0 THEN
        
        RETURN NULL;
        
    END IF;
    
    LOOP
        -- get the next piece and add it to the clob
        vPiece := DBMS_LOB.SubStr(gCLOB, 2000, nCurrentPlace);
        
        -- append this piece to the return varchar
        vReturn := vReturn || UTL_RAW.Cast_To_VarChar2
        (
            HEXTORAW(vPiece)
        );
        
        nCurrentPlace := nCurrentPlace + 2000;
        
        EXIT WHEN nLength < nCurrentPlace;
        
    END LOOP;
    
    RETURN vReturn;
    
END;
/

/*
--test
SELECT CLOB_IN_HEX_TO_VARCHAR2(EMPTY_CLOB()),
CLOB_IN_HEX_TO_VARCHAR2('313335383335303437302D323139')
FROM DUAL;
*/