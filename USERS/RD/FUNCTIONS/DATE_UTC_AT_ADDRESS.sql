CREATE OR REPLACE
FUNCTION DATE_UTC_AT_ADDRESS
(
    gDate IN DATE,
    gAddress_ID IN ADDRESS.ID%TYPE
)
RETURN DATE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vTimeZone_Name VARCHAR2(32 BYTE) := '';
    
BEGIN
    
    IF (gDate IS NULL) THEN
        
        RETURN NULL;
        
    ELSE
        
        IF (gAddress_ID IS NULL) THEN
            
            RETURN gDate;
            
        ELSE
            
            SELECT C.Name
            INTO vTimeZone_Name
            FROM ADDRESS A
            INNER JOIN GEONAMES B
                ON A.GeoNames_ID = B.ID
            INNER JOIN TIMEZONE C
                ON B.TimeZone_ID = C.ID
            WHERE A.ID = gAddress_ID;
            
        END IF;
        
        RETURN CAST
        (
            SYS_EXTRACT_UTC
            (
                FROM_TZ
                (
                    CAST(gDate AS TIMESTAMP),
                    vTimeZone_Name
                )
            )
            AS DATE
        );
        
    END IF;
    
EXCEPTION
--Handle all other cases
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT DATE_UTC_AT_ADDRESS
(
    TO_DATE('2014-12-23T01:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT ID
        FROM ADDRESS
        WHERE Country_ID = 'CYP'
        AND Name = 'Anaplasis Gym Fitness Center'
    )
)
FROM DUAL;

--UTC
SELECT DATE_UTC_AT_ADDRESS
(
    TO_DATE('2014-12-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT ID
        FROM ADDRESS
        WHERE Country_ID = 'GBR'
        AND Name = 'Zone Gym - Wood Green'
    )
)
FROM DUAL;

--BST
SELECT DATE_UTC_AT_ADDRESS
(
    TO_DATE('2014-06-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT ID
        FROM ADDRESS
        WHERE Country_ID = 'GBR'
        AND Name = 'Zone Gym - Wood Green'
    )
)
FROM DUAL;

SELECT DATE_UTC_AT_ADDRESS
(
    NULL,
    (
        SELECT ID
        FROM ADDRESS
        WHERE Country_ID = 'GBR'
        AND Name = 'Zone Gym - Wood Green'
    )
)
FROM DUAL;

SELECT DATE_UTC_AT_ADDRESS
(
    TO_DATE('2014-06-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    NULL
)
FROM DUAL;
*/