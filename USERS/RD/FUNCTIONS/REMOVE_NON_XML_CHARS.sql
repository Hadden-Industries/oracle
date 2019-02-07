CREATE OR REPLACE
FUNCTION REMOVE_NON_XML_CHARS(gString IN VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN TRANSLATE
    (
        gString,
        CHR(0)
        || CHR(1)
        || CHR(2)
        || CHR(3)
        || CHR(4)
        || CHR(5)
        || CHR(6)
        || CHR(7)
        || CHR(8)
        --
        --
        || CHR(11)
        || CHR(12)
        --
        || CHR(14)
        || CHR(15)
        || CHR(16)
        || CHR(17)
        || CHR(18)
        || CHR(19)
        || CHR(20)
        || CHR(21)
        || CHR(22)
        || CHR(23)
        || CHR(24)
        || CHR(25)
        || CHR(26)
        || CHR(27)
        || CHR(28)
        || CHR(29)
        || CHR(30)
        || CHR(31),
        CHR(0)
    );
    
END;
/