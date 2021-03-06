CREATE OR REPLACE
FUNCTION SYSDATE_UTC
RETURN DATE
PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE);
    
END;
/

/*
--test
SELECT SYSDATE,
SYSDATE_UTC
FROM DUAL
;
*/