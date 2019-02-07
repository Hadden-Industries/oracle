CREATE OR REPLACE
FUNCTION NUMBER_SPELL(gNumber IN NUMBER)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    TYPE tArray IS TABLE OF VARCHAR2(255);
    
    lArray tArray:= tArray
    (
        '',
        ' Thousand ',
        ' Million ',
        ' Billion ',
        ' Trillion ',
        ' Quadrillion ',
        ' Quintillion ',
        ' Sextillion ',
        ' Septillion ',
        ' Octillion ',
        ' Nonillion ',
        ' Decillion ',
        ' Undecillion ',
        ' Duodecillion '
    );
    
    vNumber VARCHAR2(50 BYTE) DEFAULT TRUNC(gNumber);
    vReturn VARCHAR2(4000 BYTE);
    
BEGIN
    
    FOR i IN 1 .. lArray.COUNT LOOP
        
        EXIT WHEN vNumber IS NULL;
        
        IF (SUBSTRB(vNumber, LENGTHB(vNumber) - 2, 3) <> 0) THEN
            
            vReturn := TO_CHAR
            (
                TO_DATE
                (
                    SUBSTRB
                    (
                        vNumber,
                        LENGTHB(vNumber) - 2,
                        3
                    ),
                    'J',
                    'nls_calendar = ''gregorian'''
                ),
                'Jsp', 'nls_calendar=''gregorian'''
            )
            || lArray(i)
            || vReturn;
            
        END IF;
        
        vNumber := SUBSTRB(vNumber, 1, LENGTHB(vNumber) - 3);
        
    END LOOP;
    
    RETURN vReturn;
    
END;
/

/*
--test
SELECT NUMBER_SPELL(53734555555585)
FROM DUAL;
*/