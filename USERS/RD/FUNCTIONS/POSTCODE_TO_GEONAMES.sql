CREATE OR REPLACE
FUNCTION POSTCODE_TO_GEONAMES
(
    gPostcode IN VARCHAR2,
    gCountry_ID IN CHAR DEFAULT 'GBR',
    gCountrySubdiv_Code IN VARCHAR2 DEFAULT NULL
)
RETURN INTEGER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    nGeoNames_ID GEONAMES.ID%TYPE := NULL;
    
BEGIN
    
    IF gCountry_ID <> 'GBR' THEN
        
        RETURN NULL;
        
    END IF;
    
    BEGIN
        
        WITH RESULTS AS
        (
            SELECT /*+ MATERIALIZE */
            B.Postcode,
            A.ID AS GeoNames_ID,
            GeoNamesFeatureCode_ID,
            SDO_NN_DISTANCE(1) AS Distance
            FROM GEONAMES A
            CROSS JOIN GBRPOSTCODE B
            WHERE A.GeoNamesFeatureClass_ID = 'P'
            AND B.Postcode = REPLACE
            (
                UPPER(gPostcode), CHR(32)
            )
            AND SDO_NN(A.Geometry, B.Geometry, 'sdo_batch_size=100', 1) = 'TRUE'
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
SELECT *
FROM GEONAMES
WHERE ID = POSTCODE_TO_GEONAMES('n22 7ay')
;

SELECT *
FROM GEONAMES
WHERE ID = POSTCODE_TO_GEONAMES('LN5 7EX')
;

SELECT *
FROM GEONAMES
WHERE ID = POSTCODE_TO_GEONAMES('W11 4AJ')
;

SELECT *
FROM GEONAMES
WHERE ID = POSTCODE_TO_GEONAMES('W11')
;
*/