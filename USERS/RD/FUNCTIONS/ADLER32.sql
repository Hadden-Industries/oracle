--http://technology.amis.nl/2010/03/13/utl_compress-gzip-and-zlib/

CREATE OR REPLACE
FUNCTION ADLER32(gBlob IN BLOB)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    S1 PLS_INTEGER := 1;
    S2 PLS_INTEGER := 0;
    
BEGIN
    
    FOR I IN 1 .. DBMS_LOB.GetLength(gBlob)
    LOOP
        
        S1 := MOD
        (
            S1 + TO_NUMBER
            (
                RAWTOHEX
                (
                    DBMS_LOB.SUBSTR(gBlob, 1, I)
                ),
                'XX'
            ),
            65521
        );
        S2 := MOD(S2 + S1, 65521);
        
    END LOOP;
    
    RETURN TO_CHAR( S2, 'fm0XXX' ) || TO_CHAR( S1, 'fm0XXX' );
    
END;
/