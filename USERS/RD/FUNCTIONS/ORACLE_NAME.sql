CREATE OR REPLACE
FUNCTION ORACLE_NAME(gObject_Name IN VARCHAR2)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    RETURN SUBSTRB
    (
        REGEXP_REPLACE
        (
            UPPER(gObject_Name),
            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#_]',
            ''
        ),
        1,
        128
    );
    
END;
/