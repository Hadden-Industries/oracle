CREATE OR REPLACE
FUNCTION UNIXTIME_TO_DATE(gUnixTime IN INTEGER)
RETURN DATE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    --UNIX epoch
    RETURN TO_DATE('1970-01-01', 'YYYY-MM-DD') + ((gUnixTime)/(24*60*60));
    
END;
/

/*
--test
SELECT 484056000,
UNIXTIME_TO_DATE(484056000)
FROM DUAL;
--Sat, 04 May 1985
*/