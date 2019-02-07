CREATE OR REPLACE
FUNCTION MATCH_TO_LANGUAGE(gText IN VARCHAR2)
RETURN LANGUAGE.ID%TYPE
PARALLEL_ENABLE
DETERMINISTIC
AS
    
    PRAGMA UDF;
    
    vLanguage_ID LANGUAGE.ID%TYPE := NULL;
    
BEGIN
    
    SELECT COALESCE
    (
        (
            SELECT ID
            FROM LANGUAGE
            WHERE Part1 = gText
        ),
        --http://en.wikipedia.org/wiki/ISO_639-2#B_and_T_codes
        (
            SELECT ID
            FROM LANGUAGE
            WHERE Part2T = gText
        ),
        (
            SELECT ID
            FROM LANGUAGE
            WHERE Part2B = gText
        ),
        (
            SELECT ID
            FROM LANGUAGE
            WHERE ID = gText
        ),
        (
            SELECT ID
            FROM LANGUAGE
            WHERE Name = 'Undetermined'
        )
    ) AS Language_ID
    INTO vLanguage_ID
    FROM DUAL;
    
    RETURN vLanguage_ID;
    
END;
/

/*
--test
SELECT MATCH_TO_LANGUAGE('es')
FROM DUAL;
*/