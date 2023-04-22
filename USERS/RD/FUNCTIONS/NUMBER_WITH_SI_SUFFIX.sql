CREATE OR REPLACE
FUNCTION NUMBER_WITH_SI_SUFFIX
(
    gNumber IN NUMBER,
    gSignificantDigits IN NUMBER DEFAULT 0
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    nNumber NUMBER := 0;
    vNumber VARCHAR2(32767 BYTE) := '';
    
BEGIN
    
    IF gSignificantDigits > 0 AND gNumber > 0 THEN
        
        nNumber := ROUND(gNumber, (gSignificantDigits - 1) - FLOOR(LOG(10, ABS(gNumber))));
        
    ELSE
        
        nNumber := gNumber;
        
    END IF;
    
    --(SELECT MAX(Multiplier) FROM SIPREFIX)
    IF nNumber BETWEEN 1000 AND 1000000000000000000000000000000 THEN
        
        SELECT nNumber/Multiplier || ' ' || ID
        INTO vNumber
        FROM SIPREFIX
        WHERE Multiplier >= 1000
        AND REMAINDER(Multiplier, 1000) = 0
        AND nNumber/Multiplier BETWEEN 1 AND 1000;
        
    ELSE
        
        vNumber := TO_CHAR(nNumber);
        
    END IF;
    
    RETURN vNumber;
    
END;
/

/*
--test
SELECT NUMBER_WITH_SI_SUFFIX(47020551, 1)
FROM DUAL;
*/