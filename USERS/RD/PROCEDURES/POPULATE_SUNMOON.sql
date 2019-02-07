SET DEFINE OFF;

CREATE OR REPLACE
PROCEDURE POPULATE_SUNMOON
(
    gGeometry IN MDSYS.SDO_GEOMETRY,
    gDateX IN DATE DEFAULT SYSDATE_UTC
)
AS
    
    vResponse VARCHAR2(2000 BYTE);
    tGeometry MDSYS.SDO_GEOMETRY;
    vError VARCHAR2(100 BYTE);
    
BEGIN
    
    tGeometry := CASE gGeometry.SDO_SRID
        --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
        WHEN 4326 THEN gGeometry
        ELSE SDO_CS.Transform
        (
            gGeometry,
            4326
        )
    END;
    
    --Round to ~11.1 m
    tGeometry.SDO_POINT.X := ROUND(tGeometry.SDO_POINT.X, 4);
    tGeometry.SDO_POINT.Y := ROUND(tGeometry.SDO_POINT.Y, 4);
    
    vResponse := UTL_HTTP.Request
    (
       url => 'http://api.usno.navy.mil/rstt/oneday?date='
       || EXTRACT(MONTH FROM gDateX) || '/'
       || EXTRACT(DAY FROM gDateX) || '/'
       || EXTRACT(YEAR FROM gDateX)
       || '&coords='
       || TRIM
       (
           TO_CHAR
           (
               tGeometry.SDO_POINT.Y,
               '90.9999'
           )
       ) || ',' || TRIM
       (
           TO_CHAR
           (
               tGeometry.SDO_POINT.X,
               '990.9999'
           )
       ) || '&tz=0'
    );
    
    SELECT JSON_VALUE(vResponse, '$.error')
    INTO vError
    FROM DUAL;
    
    IF (vError = 'false') THEN
        
        INSERT
        INTO SUNMOON
        (
            DATEX,
            GEOMETRY,
            JSON,
            COMMENTS
        )
        VALUES
        (
            TRUNC(gDateX),
            tGeometry,
            vResponse,
            ''
        );
        
    END IF;
    
EXCEPTION
WHEN OTHERS THEN
    
    NULL;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;

DECLARE
    
    tGeometry MDSYS.SDO_GEOMETRY;
    
BEGIN
    
    SELECT Geometry
    INTO tGeometry
    FROM GBRPOSTCODE
    WHERE Postcode =
    (
        SELECT REPLACE(Postcode, ' ')
        FROM ADDRESS
        --Zone Gym - Wood Green
        WHERE GooglePlaceID = 'ChIJRSRXRuEbdkgRrbIU6rusNy0'
    );
    
    POPULATE_SUNMOON
    (
        tGeometry,
        TO_DATE('2016-07-12T21:35:16', 'YYYY-MM-DD"T"HH24:MI:SS')
    );
    
END;
/

--Populate missing values
BEGIN
    
    FOR A IN
    (
        SELECT COALESCE(C.Geometry, D.Geometry) AS Geometry,
        TRUNC(A.DateTimeEnd) AS DateX
        FROM
        (
            SELECT B.ID AS Workout_ID,
            C.DateTimeEnd,
            B.Address_ID
            FROM WORKOUT B
            INNER JOIN
            (
                SELECT Workout_ID,
                MAX(DateTimeStart) + NUMTODSINTERVAL(1, 'MINUTE') AS DateTimeEnd
                FROM EXERCISESET
                WHERE IsCompleted = 'T'
                HAVING MIN(DateTimeStart) != MAX(DateTimeStart)
                GROUP BY Workout_ID
            ) C
                ON B.ID = C.Workout_ID
            WHERE B.IsCompleted = 'T'
        ) A
        INNER JOIN ADDRESS B
            ON A.Address_ID = B.ID
        LEFT OUTER JOIN GBRPOSTCODE C
            ON B.Country_ID = C.Country_ID
                    AND REPLACE(B.Postcode, ' ') = C.Postcode
        LEFT OUTER JOIN GEONAMES D
            ON B.GeoNames_ID = D.ID
        LEFT OUTER JOIN SUNMOON E
            ON TRUNC(A.DateTimeEnd) = E.DateX
                    AND ROUND
                    (
                        COALESCE(C.GEOMETRY.SDO_POINT.X, D.GEOMETRY.SDO_POINT.X),
                        4
                    ) = ROUND(E.GEOMETRY.SDO_POINT.X, 4)
                    AND ROUND
                    (
                        COALESCE(C.GEOMETRY.SDO_POINT.Y, D.GEOMETRY.SDO_POINT.Y),
                        4
                    ) = ROUND(E.GEOMETRY.SDO_POINT.Y, 4)
        WHERE E.JSON IS NULL
    ) LOOP
        
        POPULATE_SUNMOON
        (
            A.Geometry,
            A.DateX
        );
        
        COMMIT;
        
        DBMS_LOCK.Sleep(1);
        
    END LOOP;
    
END;
/
*/