CREATE OR REPLACE
FUNCTION BLOB_TO_CLOB
(
    L_BLOB IN BLOB,
    gCharacterSet IN VARCHAR2 DEFAULT NULL --AL32UTF8 should be the Oracle default
)
RETURN CLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    L_CLOB CLOB;
    L_SRC_OFFSET NUMBER := 1;
    L_DEST_OFFSET NUMBER := 1;
    L_BLOB_CSID NUMBER := COALESCE
    (
        NLS_CHARSET_ID(gCharacterSet),
        DBMS_LOB.Default_CSID
    );
    V_LANG_CONTEXT NUMBER := DBMS_LOB.Default_Lang_Ctx;
    L_WARNING NUMBER;
    L_AMOUNT NUMBER := DBMS_LOB.GetLength(L_BLOB);
    
BEGIN
    
    DBMS_LOB.CreateTemporary(L_CLOB, TRUE);
    
    IF L_AMOUNT > 0 THEN
        
        DBMS_LOB.ConvertToClob
        (
            L_CLOB,
            L_BLOB,
             L_AMOUNT,
            L_SRC_OFFSET,
            L_DEST_OFFSET,
            L_BLOB_CSID,
            V_LANG_CONTEXT,
            L_WARNING
        );
        
    --passing a 0/NULL size BLOB should not lead to a failure, just return an empty CLOB
    ELSE
        
        L_CLOB := EMPTY_CLOB();
        
    END IF;
    
    IF (L_WARNING = DBMS_LOB.Warn_Inconvertible_Char) THEN
        
        DBMS_OUTPUT.Put_Line('Warning: Inconvertible character');
        
    END IF;
    
    RETURN L_CLOB;
    
END;
/