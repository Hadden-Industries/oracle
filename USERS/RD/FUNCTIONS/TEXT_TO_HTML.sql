CREATE OR REPLACE
FUNCTION TEXT_TO_HTML(gText IN VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS

    PRAGMA UDF;

BEGIN
    
    RETURN REPLACE
    (
        REGEXP_REPLACE
        (
            ASCIISTR
            (
                HTF.ESCAPE_SC
                (
                    gText
                )
            ),
            '(\\([[:xdigit:]]{4}))',
            '&#x\2;'
        ),
        '''',
        '&#39;'
    );
    
END;
/

--test
/*SELECT Text_to_HTML('Sãoコ')
FROM DUAL
;
;*/

--the reason UTL_I18N.ESCAPE_REFERENCE is inadequate
/*SELECT UTL_I18N.ESCAPE_REFERENCE('✓č', 'us7ascii')
, TEXT_TO_HTML('✓č')
FROM DUAL
;*/