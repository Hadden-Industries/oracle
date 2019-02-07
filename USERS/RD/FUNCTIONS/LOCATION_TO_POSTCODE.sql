CREATE OR REPLACE
FUNCTION LOCATION_TO_POSTCODE
(
    gLatitude IN NUMBER,
    gLongitude IN NUMBER,
    gCountry_ID IN CHAR DEFAULT 'GBR'
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vPostcode ADDRESS.Postcode%TYPE := NULL;
    
BEGIN
    
    IF gCountry_ID != 'GBR' THEN
        
        RETURN NULL;
        
    END IF;
    
    BEGIN
        
        WITH RESULTS AS
        (
            SELECT /*+ MATERIALIZE */
            PostcodeeGIF,
            SDO_NN_DISTANCE(1) AS Distance
            FROM GBRPOSTCODE AS OF PERIOD FOR VALID_TIME SYSDATE
            WHERE SDO_NN
            (
              Geometry,
              SDO_GEOMETRY
              (
                  2001,
                  4326, --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                  SDO_POINT_TYPE
                  (
                      gLongitude,
                      gLatitude,
                      NULL
                  ),
                  NULL,
                  NULL
              ),
              'sdo_batch_size=100',
              1
            ) = 'TRUE'
            AND ROWNUM <= 5
        )
        --
        SELECT PostcodeeGIF
        INTO vPostcode
        FROM
        (
            SELECT PostcodeeGIF,
            ROW_NUMBER() OVER (ORDER BY Distance) AS RN
            FROM RESULTS
        )
        WHERE RN = 1;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    RETURN vPostcode;
    
END;
/

/*
--test
SELECT LOCATION_TO_POSTCODE
(
    gLatitude => 51.586749700000006,
    gLongitude => -0.0824036,
    gCountry_ID => 'GBR'
)
FROM DUAL;
*/