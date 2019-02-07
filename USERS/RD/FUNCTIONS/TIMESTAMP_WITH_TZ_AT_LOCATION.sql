CREATE OR REPLACE
FUNCTION TIMESTAMP_WITH_TZ_AT_LOCATION
(
    gTimeStamp IN TIMESTAMP,
    gLocation_ID IN LOCATION.ID%TYPE
)
RETURN TIMESTAMP WITH TIME ZONE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vTimeZone_Name VARCHAR2(32 BYTE) := '';
    
BEGIN
    
    IF (gTimeStamp IS NULL) THEN
        
        RETURN NULL;
        
    ELSE
        
        IF (gLocation_ID IS NULL) THEN
            
            RETURN gTimeStamp;
            
        ELSE
            
            SELECT Name
            INTO vTimeZone_Name
            FROM
            (
                SELECT B.Name,
                ROW_NUMBER() OVER (ORDER BY A.Distance) AS RN
                FROM
                (
                    SELECT B.TimeZone_ID,
                    SDO_NN_DISTANCE(1) AS Distance
                    FROM LOCATION A
                    CROSS JOIN GEONAMES B
                    WHERE A.ID = gLocation_ID
                    AND SDO_NN
                    (
                      B.Geometry,
                      SDO_CS.Make_2D(A.Geometry, A.Geometry.SDO_SRID),
                      'sdo_batch_size=100',
                      1
                    ) = 'TRUE'
                    AND ROWNUM <= 5
                ) A
                INNER JOIN TIMEZONE B
                    ON A.TimeZone_ID = B.ID
            )
            WHERE RN = 1;
            
        END IF;
        
        RETURN FROM_TZ(gTimeStamp, vTimeZone_Name);
        
    END IF;
    
EXCEPTION
--Handle all other cases
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT TIMESTAMP_WITH_TZ_AT_LOCATION
(
    TO_TIMESTAMP('2014-12-23T01:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT Location_ID
        FROM ADDRESS#LOCATION
        WHERE Address_ID =
        (
            SELECT ID
            FROM ADDRESS
            WHERE Country_ID = 'CYP'
            AND Name = 'Anaplasis Gym Fitness Center'
        )
    )
)
FROM DUAL;

--UTC
SELECT TIMESTAMP_WITH_TZ_AT_LOCATION
(
    TO_TIMESTAMP('2014-12-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT Location_ID
        FROM ADDRESS#LOCATION
        WHERE Address_ID =
        (
            SELECT ID
            FROM ADDRESS
            WHERE Country_ID = 'GBR'
            AND Name = 'Zone Gym - Wood Green'
        )
    )
)
FROM DUAL;

--BST
SELECT TIMESTAMP_WITH_TZ_AT_LOCATION
(
    TO_TIMESTAMP('2014-06-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    (
        SELECT Location_ID
        FROM ADDRESS#LOCATION
        WHERE Address_ID =
        (
            SELECT ID
            FROM ADDRESS
            WHERE Country_ID = 'GBR'
            AND Name = 'Zone Gym - Wood Green'
        )
    )
)
FROM DUAL;

SELECT TIMESTAMP_WITH_TZ_AT_LOCATION
(
    NULL,
    (
        SELECT Location_ID
        FROM ADDRESS#LOCATION
        WHERE Address_ID =
        (
            SELECT ID
            FROM ADDRESS
            WHERE Country_ID = 'GBR'
            AND Name = 'Zone Gym - Wood Green'
        )
    )
)
FROM DUAL;

SELECT TIMESTAMP_WITH_TZ_AT_LOCATION
(
    TO_TIMESTAMP('2014-06-23T21:00:00', 'YYYY-MM-DD"T"HH24:MI:SS'),
    NULL
)
FROM DUAL;
*/