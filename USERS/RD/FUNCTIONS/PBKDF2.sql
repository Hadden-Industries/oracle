--http://mikepargeter.wordpress.com/2012/11/26/pbkdf2-in-oracle/

CREATE OR REPLACE
FUNCTION PBKDF2
(
    gPassword IN VARCHAR2,
    gSalt IN VARCHAR2,
    gCount IN INTEGER,
    gKeyLength IN INTEGER
)
RETURN VARCHAR2
AS
    
    l_block_count INTEGER := 0;
    l_last RAW(32767) := '';
    l_xorsum RAW(32767) := '';
    l_result RAW(32767) := '';
    
BEGIN
    
    l_block_count := ceil(gKeyLength / 20);  --20 bytes for SHA1
    
    FOR i IN 1..l_block_count LOOP
        
        l_last := UTL_RAW.Concat(UTL_RAW.Cast_To_Raw(gSalt), UTL_RAW.Cast_From_Binary_Integer(i, UTL_RAW.big_endian));
        
        l_xorsum := NULL;
        
        FOR j IN 1..gCount LOOP
            
            l_last := DBMS_CRYPTO.Mac(l_last, DBMS_CRYPTO.HMAC_SH1, UTL_RAW.Cast_To_Raw(gPassword));
            
            IF l_xorsum IS NULL THEN
                
                l_xorsum := l_last;
                
            ELSE
                
                l_xorsum := UTL_RAW.Bit_XOR(l_xorsum, l_last);
                
            END IF;
            
        END LOOP;
        
        l_result := UTL_RAW.Concat(l_result, l_xorsum);
        
    END LOOP;
    
    RETURN RAWTOHEX(UTL_RAW.Substr(l_result, 1, gKeyLength));
    
END;
/

--test
SELECT t.*,
PBKDF2
(
    Password,
    Salt,
    Iterations,
    Key_Length
) AS Output
FROM
(
    SELECT 'password' AS Password,
    'salt' AS Salt,
    1 AS Iterations,
    20 AS Key_Length,
    '0C60C80F961F0E71F3A9B524AF6012062FE037A6' AS Expected_output
    FROM DUAL
    --
    UNION ALL
    --
    SELECT 'password',
    'salt',
    2,
    20,
    'EA6C014DC72D6F8CCD1ED92ACE1D41F0D8DE8957'
    FROM DUAL
    --
    UNION ALL
    --
    SELECT 'password',
    'salt',
    4096,
    20,
    '4B007901B765489ABEAD49D926F721D065A429C1'
    FROM DUAL
    /*--
    UNION ALL
    --
    SELECT 'password',
    'salt',
    16777216,
    20,
    'EEFE3D61CD4DA4E4E9945B3D6BA2158C2634E984'
    FROM DUAL*/
    --
    UNION ALL
    --
    SELECT 'passwordPASSWORDpassword',
    'saltSALTsaltSALTsaltSALTsaltSALTsalt',
    4096,
    25,
    '3D2EEC4FE41C849B80C8D83662C0E44A8B291A964CF2F07038'
    FROM DUAL
    --
    UNION ALL
    --
    SELECT 'pass'||chr(0)||'word',
    'sa'||chr(0)||'lt',
    4096,
    16,
    '56FA6AA75548099DCC37D7F03425E0C3'
    FROM DUAL
) t;
--78 secs for all