--For positive integers
CREATE OR REPLACE
FUNCTION INTEGER_TO_WORD(gInteger IN INTEGER)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    --The Associated Press Stylebook
    RETURN CASE gInteger
        WHEN 1 THEN 'one'
        WHEN 2 THEN 'two'
        WHEN 3 THEN 'three'
        WHEN 4 THEN 'four'
        WHEN 5 THEN 'five'
        WHEN 6 THEN 'six'
        WHEN 7 THEN 'seven'
        WHEN 8 THEN 'eight'
        WHEN 9 THEN 'nine'
        ELSE TO_CHAR(gInteger)
    END;
    
END;
/

/*
--test
SELECT INTEGER_TO_WORD(0) AS Num
FROM DUAL;

SELECT INTEGER_TO_WORD(2) AS Num
FROM DUAL;
*/