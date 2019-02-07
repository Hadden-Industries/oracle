CREATE OR REPLACE
FUNCTION CLOB_IN_HEX_TO_BLOB(gCLOB IN CLOB)
RETURN BLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    bData BLOB := EMPTY_BLOB();
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
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => bData,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open
    (
        bData,
        DBMS_LOB.LOB_READWRITE
    );
    
    LOOP
        -- get the next piece and add it to the clob
        vPiece := DBMS_LOB.SubStr(gCLOB, 2000, nCurrentPlace);
        
        -- append this piece to the BLOB
        DBMS_LOB.WriteAppend(bData, LENGTHB(vPiece)/2, HEXTORAW(vPiece));
        
        nCurrentPlace := nCurrentPlace + 2000;
        
        EXIT WHEN nLength < nCurrentPlace;
        
    END LOOP;
    
    RETURN bData;
    
END;
/

/*
--test
SELECT Record_ID,
Crop_X,
Crop_Y,
Crop_Width,
CLOB_IN_HEX_TO_BLOB(Data_) AS BLOB$Data_
FROM ABFULLSIZEIMAGE
WHERE Record_ID = 120;
*/