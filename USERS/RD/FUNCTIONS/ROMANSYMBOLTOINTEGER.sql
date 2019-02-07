CREATE OR REPLACE
FUNCTION ROMANSYMBOLTOINTEGER(RomanSymbol IN CHAR)
RETURN INTEGER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN CASE RomanSymbol
        WHEN 'M' THEN 1000
        WHEN 'Ⅿ' THEN 1000
        WHEN 'D' THEN 500
        WHEN 'Ⅾ' THEN 500
        WHEN 'C' THEN 100
        WHEN 'Ⅽ' THEN 100
        WHEN 'L' THEN 50
        WHEN 'Ⅼ' THEN 50
        WHEN 'Ⅻ' THEN 12
        WHEN 'Ⅺ' THEN 11
        WHEN 'X' THEN 10
        WHEN 'Ⅹ' THEN 10
        WHEN 'Ⅸ' THEN 9
        WHEN 'Ⅷ' THEN 8
        WHEN 'Ⅶ' THEN 7
        WHEN 'Ⅵ' THEN 6
        WHEN 'V' THEN 5
        WHEN 'Ⅴ' THEN 5
        WHEN 'Ⅳ' THEN 4
        WHEN 'Ⅲ' THEN 3
        WHEN 'Ⅱ' THEN 2
        WHEN 'I' THEN 1
        WHEN 'Ⅰ' THEN 1
        ELSE NULL
    END;
    
END;
/

/*
--test
SELECT ROMANSYMBOLTOINTEGER('M') AS Num
FROM DUAL;
*/