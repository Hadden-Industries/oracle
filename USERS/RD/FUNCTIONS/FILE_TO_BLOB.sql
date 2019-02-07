CREATE OR REPLACE
FUNCTION FILE_TO_BLOB(gFileName IN VARCHAR2)
RETURN BLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    l_BFile BFILE := BFILENAME('RD', gFileName);
    L_BLOB BLOB;
    L_SRC_OFFSET NUMBER := 1;
    L_DEST_OFFSET NUMBER := 1;
    
BEGIN
    
    DBMS_LOB.OPEN(l_BFile, DBMS_LOB.LOB_READONLY);
    
    DBMS_LOB.CREATETEMPORARY(L_BLOB, TRUE);
    
    DBMS_LOB.LOADBLOBFROMFILE
    (
        dest_lob => L_BLOB,
        src_bfile => l_BFile,
        amount => DBMS_LOB.LOBMAXSIZE,
        dest_offset => L_SRC_OFFSET,
        src_offset => L_DEST_OFFSET
    );
    
    DBMS_LOB.CLOSE(l_BFile);
    
    RETURN L_BLOB;

END;
/