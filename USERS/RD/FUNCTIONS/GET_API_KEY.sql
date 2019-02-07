CREATE OR REPLACE
FUNCTION GET_API_KEY
(
    gName VARCHAR2,
    gProductOrService_Name VARCHAR2 DEFAULT 'Jym'
)
RETURN VARCHAR2
PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    r VARCHAR2(4000 BYTE) := '';
    
BEGIN
    
    SELECT Value
    INTO r
    FROM APIKEY AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) 
    WHERE ProductOrService_ID =
    (
        SELECT ProductOrService_ID
        FROM APP
        WHERE Name = gProductOrService_Name
    )
    AND Name = gName;
    
    RETURN r;
    
EXCEPTION
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT GET_API_KEY('Companies House')
FROM DUAL;
*/