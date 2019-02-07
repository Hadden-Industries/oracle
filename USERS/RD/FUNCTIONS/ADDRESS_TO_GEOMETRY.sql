CREATE OR REPLACE
FUNCTION ADDRESS_TO_GEOMETRY
(
    gAddress_ID IN ADDRESS.ID%TYPE
)
RETURN SDO_GEOMETRY
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    r SDO_GEOMETRY;
    
BEGIN
    
    SELECT COALESCE(B.Geometry, C.Geometry, D.Geometry)
    INTO r
    FROM ADDRESS A
    LEFT OUTER JOIN
    (
        SELECT A.Address_ID,
        B.Geometry
        FROM ADDRESS#LOCATION A
        INNER JOIN LOCATION B
            ON A.Location_ID = B.ID
        WHERE A.AddressToLocationType_ID =
        (
            SELECT ID
            FROM ADDRESSTOLOCATIONTYPE
            WHERE Name = 'Delivery Point'
        )
    ) B
        ON A.ID = B.Address_ID
    LEFT OUTER JOIN GBRPOSTCODE C
        ON A.Country_ID = C.Country_ID
                AND REPLACE(A.Postcode, ' ') = C.Postcode
    LEFT OUTER JOIN GEONAMES D
        ON A.GeoNames_ID = D.ID
    WHERE A.ID = gAddress_ID;
    
    RETURN r;
    
END;
/

/*
--test
SELECT DateTimeStart,
Address_ID,
ADDRESS_TO_GEOMETRY(Address_ID) AS Geometry
FROM WORKOUT
WHERE Person_ID = 1
ORDER BY DateTimeStart;
*/