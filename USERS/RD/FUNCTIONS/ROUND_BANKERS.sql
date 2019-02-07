CREATE OR REPLACE
FUNCTION ROUND_BANKERS
(
    gValue IN NUMBER,
    gCurrency_ID IN CURRENCY.ID%TYPE DEFAULT 'GBP'
)
RETURN NUMBER
PARALLEL_ENABLE DETERMINISTIC
AS
    
    PRAGMA UDF;
    
    nDecimalPlaces PLS_INTEGER := 2;
    nRemainder NUMBER := 0;
    
BEGIN
    
    IF gCurrency_ID <> 'GBP' THEN
        
        SELECT COALESCE(MinorUnit, 2)
        INTO nDecimalPlaces
        FROM CURRENCY
        WHERE ID = gCurrency_ID;
        
    END IF;
    
    nRemainder := ABS((gValue - TRUNC(gValue, nDecimalPlaces)) * 1000);
    
    IF
    (
        nRemainder < 5
        OR
        (
            nRemainder = 5
            AND MOD(TRUNC(gValue * 100), nDecimalPlaces) = 0
        )
    ) THEN
        
        RETURN TRUNC(gValue, nDecimalPlaces);
        
    ELSE
        
        RETURN ROUND(gValue, nDecimalPlaces);
        
    END IF;
    
END;
/

/*
--test default
SELECT ROUND_BANKERS(1.23534)
FROM DUAL;

--test three decimal places
SELECT ROUND_BANKERS(1.23534, 'TND')
FROM DUAL;

--test 0 decimal places
SELECT ROUND_BANKERS(1.23534, 'RWF')
FROM DUAL;
*/