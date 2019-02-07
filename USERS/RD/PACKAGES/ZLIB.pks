--http://technology.amis.nl/2010/03/13/utl_compress-gzip-and-zlib/

CREATE OR REPLACE
PACKAGE ZLIB
AS
    
    FUNCTION COMPRESS_(gBlob IN BLOB)
    RETURN BLOB;
    
    FUNCTION DECOMPRESS(gBlob IN BLOB )
    RETURN BLOB;
    
END;
/