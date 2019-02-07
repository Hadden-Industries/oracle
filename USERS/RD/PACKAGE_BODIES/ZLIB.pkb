CREATE OR REPLACE
PACKAGE BODY ZLIB
AS

FUNCTION COMPRESS_(gBlob IN BLOB)
RETURN BLOB
AS
    
    T_TMP BLOB;
    T_CPR BLOB;
    
BEGIN
    
    T_TMP := UTL_COMPRESS.LZ_COMPRESS(gBlob);
    
    DBMS_LOB.CREATETEMPORARY(T_CPR, FALSE);
    
    T_CPR := HEXTORAW( '789C' ); -- zlib header
    
    DBMS_LOB.COPY(T_CPR, T_TMP, DBMS_LOB.GETLENGTH(T_TMP) - 10 - 8, 3, 11);
    
    DBMS_LOB.APPEND
    (
        T_CPR,
        HEXTORAW
        (
            ADLER32(gBlob)
        )
    ); -- zlib trailer
    
    DBMS_LOB.FREETEMPORARY(T_TMP);
    
    RETURN T_CPR;
    
END;

FUNCTION DECOMPRESS(gBlob IN BLOB )
RETURN BLOB
AS
    
    T_OUT BLOB;
    T_TMP BLOB;
    T_BUFFER RAW(1);
    T_HDL BINARY_INTEGER;
    T_S1 PLS_INTEGER; -- s1 part of adler32 checksum
    T_LAST_CHR PLS_INTEGER;
    
BEGIN
    
    DBMS_LOB.CREATETEMPORARY( T_OUT, FALSE );
    
    DBMS_LOB.CREATETEMPORARY( T_TMP, FALSE );
    
    T_TMP := HEXTORAW( '1F8B0800000000000003' ); -- gzip header
    
    DBMS_LOB.COPY( T_TMP, gBlob, DBMS_LOB.GETLENGTH(gBlob) - 2 - 4, 11, 3 );
    
    DBMS_LOB.APPEND( T_TMP, HEXTORAW( '0000000000000000' ) ); -- add a fake trailer
    
    T_HDL := UTL_COMPRESS.LZ_UNCOMPRESS_OPEN( T_TMP );
    
    T_S1 := 1;
    
    LOOP
        
        BEGIN
            
            UTL_COMPRESS.LZ_UNCOMPRESS_EXTRACT( T_HDL, T_BUFFER );
            
        EXCEPTION
        WHEN OTHERS THEN
            
            EXIT;
            
        END;
        
        DBMS_LOB.APPEND( T_OUT, T_BUFFER );
        
        T_S1 := MOD( T_S1 + TO_NUMBER( RAWTOHEX( T_BUFFER ), 'xx' ), 65521 );
        
    END LOOP;
    
    T_LAST_CHR := TO_NUMBER( DBMS_LOB.SUBSTR(gBlob, 2, DBMS_LOB.GETLENGTH(gBlob) - 1 ), '0XXX') - T_S1;
    
    IF T_LAST_CHR < 0 THEN
        
        T_LAST_CHR := T_LAST_CHR + 65521;
        
    END IF;
    
    DBMS_LOB.APPEND( T_OUT, HEXTORAW( TO_CHAR( T_LAST_CHR, 'fm0X' ) ) );
    
    IF UTL_COMPRESS.ISOPEN( T_HDL ) THEN
        
        UTL_COMPRESS.LZ_UNCOMPRESS_CLOSE( T_HDL );
        
    END IF;
    
    DBMS_LOB.FREETEMPORARY( T_TMP );
    
    RETURN T_OUT;
    
END;

END;
/