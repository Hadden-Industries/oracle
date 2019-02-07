CREATE OR REPLACE
FUNCTION LOCATION_TO_GEONAMES
(
    gLatitude IN NUMBER,
    gLongitude IN NUMBER
)
RETURN INTEGER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    nGeoNames_ID GEONAMES.ID%TYPE := NULL;
    
BEGIN
    
    BEGIN
        
        WITH RESULTS AS
        (
            SELECT /*+ MATERIALIZE NO_INDEX(A GEONAMES_GEONAMFEATURECLASS_IX) */
            A.ID AS GeoNames_ID,
            GeoNamesFeatureCode_ID,
            SDO_NN_DISTANCE(1) AS Distance
            FROM GEONAMES A
            WHERE A.GeoNamesFeatureClass_ID = 'P'
            AND SDO_NN
            (
                A.Geometry,
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
        SELECT GeoNames_ID
        INTO nGeoNames_ID
        FROM
        (
            SELECT GeoNames_ID,
            ROW_NUMBER()
            OVER
            (
                ORDER BY Distance,
                CASE GeoNamesFeatureCode_ID
                    WHEN 'PPLC' THEN 0
                    WHEN 'PPLG' THEN 1
                    WHEN 'PPLA' THEN 2
                    WHEN 'PPLA2' THEN 3
                    WHEN 'PPLA3' THEN 4
                    WHEN 'PPLA4' THEN 5
                    WHEN 'PPL' THEN 6
                    WHEN 'PPLS' THEN 7
                    WHEN 'PPLX' THEN 8
                    WHEN 'PPLL' THEN 9
                    WHEN 'PPLF' THEN 10
                    WHEN 'PPLR' THEN 11
                    WHEN 'STLMT' THEN 12
                    WHEN 'PPLQ' THEN 13
                    WHEN 'PPLW' THEN 14
                    WHEN 'PPLCH' THEN 15
                    WHEN 'PPLH' THEN 16
                    ELSE 17
                END
            ) AS RN
            FROM RESULTS
        )
        WHERE RN = 1;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    RETURN nGeoNames_ID;
    
END;
/

/*
--test
SELECT LOCATION_TO_GEONAMES
(
    gLatitude => 51.617243802573874,
    gLongitude => -0.10338842868804932
)
FROM DUAL
;
*/