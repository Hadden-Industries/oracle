CREATE OR REPLACE
FUNCTION TO_ASCII(gText IN VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN REGEXP_REPLACE
    (
        DECOMPOSE
        (
            TRANSLATE
            (
                gText,
                'ÆæÐĐðđĦħŁłØøŒœӘәƏəIı‘’`”–',
                'AaDDddHhLlOoOoAaAaIi''''''"-'
            )
        ),
        '[^]ABCDEFGHIJKLMNOPQRSTUVWXYZ[\^_abcdefghijklmnopqrstuvwxyz0123456789 !"#$%&''()*+,./:;<=>?@{|}~-]'
    );
    
END;
/

/*
--test
SELECT TO_ASCII('Gәncә')
FROM DUAL;

--from 2014-2 UNLOCODE SecretariatNotes.pdf
SELECT TO_ASCII('À, Á, Â, Ã, Ä, Å, Æ, A') FROM DUAL;
SELECT TO_ASCII('Ç, C') FROM DUAL;
SELECT TO_ASCII('È, É, Ê, Ë, E') FROM DUAL;
SELECT TO_ASCII('Ì, Í, Î, Ï, I') FROM DUAL;
SELECT TO_ASCII('Ñ, N') FROM DUAL;
SELECT TO_ASCII('Ò, Ó, Ô, Õ, Ö, Ø, O') FROM DUAL;
SELECT TO_ASCII('Ù, Ú, Û, Ü U') FROM DUAL;
SELECT TO_ASCII('Ý, Y') FROM DUAL;
SELECT TO_ASCII('à, á, â, ã, ä, å, æ, a') FROM DUAL;
SELECT TO_ASCII('ç, c') FROM DUAL;
SELECT TO_ASCII('è, é, ê, ë, e') FROM DUAL;
SELECT TO_ASCII('ì, í, î, ï i') FROM DUAL;
SELECT TO_ASCII('ñ, n') FROM DUAL;
SELECT TO_ASCII('ò, ó, ô, õ, ö, ø, o') FROM DUAL;
SELECT TO_ASCII('ù, ú, û, ü, u') FROM DUAL;
SELECT TO_ASCII('ý, ÿ, y') FROM DUAL;
*/