CREATE OR REPLACE
FUNCTION CLOB_TO_BLOB(L_CLOB IN CLOB)
RETURN BLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    L_BLOB BLOB;
    L_SRC_OFFSET NUMBER := 1;
    L_DEST_OFFSET NUMBER := 1;
    L_BLOB_CSID NUMBER := DBMS_LOB.Default_CSID;
    V_LANG_CONTEXT NUMBER := DBMS_LOB.Default_Lang_Ctx;
    L_WARNING NUMBER;
    L_AMOUNT NUMBER := DBMS_LOB.GetLength(L_CLOB);
    
BEGIN
    
    DBMS_LOB.CREATETEMPORARY(L_BLOB, TRUE);
    
    IF L_AMOUNT > 0 THEN
        
        DBMS_LOB.ConvertToBlob
        (
            L_BLOB,
            L_CLOB,
            L_AMOUNT,
            L_SRC_OFFSET,
            L_DEST_OFFSET,
            L_BLOB_CSID,
            V_LANG_CONTEXT,
            L_WARNING
        );
        
    --passing a 0/NULL size CLOB should not lead to a failure, just return an empty BLOB
    ELSE
        
        L_BLOB := EMPTY_BLOB();
         
    END IF;
     
    IF (L_WARNING = DBMS_LOB.Warn_Inconvertible_Char) THEN
        
        DBMS_OUTPUT.Put_Line('Warning: Inconvertible character');
        
    END IF;
     
    RETURN L_BLOB;

END;
/