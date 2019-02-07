CREATE OR REPLACE
FUNCTION MACABSOLUTETIME_TO_UNIXTIME(gMacAbsoluteTime IN INTEGER)
RETURN INTEGER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    --Constant from https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDate_Class/index.html#//apple_ref/doc/c_ref/NSTimeIntervalSince1970
    RETURN (gMacAbsoluteTime + 978307200);
    
END;
/

/*
--test
SELECT First_,
Last,
Birthday,
MACABSOLUTETIME_TO_UNIXTIME
(
    TO_NUMBER(Birthday)
) AS UnixTimeBirth
FROM ABPERSON
WHERE Birthday IS NOT NULL;
*/