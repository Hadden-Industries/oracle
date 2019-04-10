CREATE OR REPLACE
FUNCTION REPEAT
(
    gString VARCHAR2,
    gTimes INTEGER DEFAULT 2
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN RPAD(gString, LENGTH(gString) * gTimes, gString);
    
END;
/

/*
--test
SELECT REPEAT('string')
FROM DUAL;

SELECT REPEAT('string', 4)
FROM DUAL;
*/