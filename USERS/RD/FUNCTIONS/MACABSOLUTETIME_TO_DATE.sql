CREATE OR REPLACE
FUNCTION MACABSOLUTETIME_TO_DATE(gMacAbsoluteTime IN INTEGER)
RETURN DATE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    --https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDate_Class/
    RETURN TO_DATE('2001-01-01', 'YYYY-MM-DD') + ((gMacAbsoluteTime)/(24*60*60));
    
END;
/

/*
--test
SELECT First_,
Last,
Birthday,
TRUNC
(
    MACABSOLUTETIME_TO_DATE
    (
        TO_NUMBER(Birthday)
    )
) AS DateBirth
FROM ABPERSON
WHERE Birthday IS NOT NULL;
--1604 is the 'Magic' value to denote unknown year
*/