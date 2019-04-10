CREATE OR REPLACE
FUNCTION TO_DATE_SAFE
(
    gText IN VARCHAR2,
    gDateFormat IN VARCHAR2 DEFAULT 'YYYY-MM-DD'
)
RETURN DATE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN TO_DATE(gText, gDateFormat);
    
EXCEPTION
--Handle all cases such as ORA-01843 for invalid month etc.
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT TO_DATE_SAFE('2014-12-23')
FROM DUAL;

SELECT TO_DATE_SAFE('20141223', 'YYYYMMDD')
FROM DUAL;

SELECT TO_DATE_SAFE('20142312', 'YYYYMMDD')
FROM DUAL;

SELECT TO_DATE_SAFE(NULL)
FROM DUAL;
*/