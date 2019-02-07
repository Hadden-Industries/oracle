CREATE OR REPLACE
FUNCTION SINGLE_LINE(gText IN VARCHAR2)
RETURN VARCHAR2
PARALLEL_ENABLE
DETERMINISTIC
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN REMOVE_NON_XML_CHARS
    (
        TRIM
        (
            --Remove trailing and leading Spaces
            BOTH CHR(32)
            --Replace multiple consecutive Spaces with single Space
            FROM REGEXP_REPLACE
            (
                --Remove Carriage Return
                REPLACE
                (
                    --Remove Line Feed
                    REPLACE
                    (
                        --Replace every Tab with Space
                        REPLACE
                        (
                            gText,
                            CHR(9),
                            CHR(32)
                        ),
                        CHR(10)
                    ),
                    CHR(13)
                ),
                '[[:blank:]]{2,}',
                CHR(32)
            )
        )
    );
    
END;
/

/*
--test
SELECT SINGLE_LINE('
   Here is 
  some text broken up   and with      many random spaces   ' || CHR(9))
FROM DUAL;
*/