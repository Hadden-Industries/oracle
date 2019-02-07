CREATE OR REPLACE
FUNCTION GEOMETRY_TO_GEOJSON
(
    gGeometry IN SDO_GEOMETRY,
    gPopupContent IN VARCHAR2 DEFAULT NULL
)
RETURN CLOB
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    j JSON_OBJECT_T;
    
BEGIN
    
    j := JSON_OBJECT_T.parse
    (
        JSON_OBJECT('type' VALUE 'Feature')
    );
    
    j.put
    (
        'geometry',
        JSON_OBJECT_T.parse
        (
            gGeometry.Get_GeoJson()
        )
    );
    
    IF gPopupContent IS NOT NULL THEN
        
        j.put
        (
            'properties',
            JSON_OBJECT_T.parse
            (
                JSON_OBJECT('popupContent' VALUE gPopupContent)
            )
        );
        
    ELSE
        
        j.put_null
        (
            'properties'
        );
        
    END IF;
    
    RETURN j.to_CLOB;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;

DECLARE
    
    cCLOB CLOB;
    
BEGIN
    
    SELECT GEOMETRY_TO_GEOJSON(Geometry, Postcode) AS GeoJSON
    --GEOMETRY_TO_GEOJSON(Geometry, NULL) AS GeoJSON_NoProperties
    INTO cCLOB
    FROM GBRPOSTCODE
    WHERE Postcode = 'LS14SF';
    
    DBMS_OUTPUT.Put_Line(cCLOB);
    
    DBMS_OUTPUT.Put_Line('Length:' || DBMS_LOB.GetLength(cCLOB));
    
END;
/
*/