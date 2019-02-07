SET DEFINE OFF;

CREATE OR REPLACE
PROCEDURE POPULATE_WEATHER
(
    gGeometry IN MDSYS.SDO_GEOMETRY,
    gDateTimeX IN DATE DEFAULT NULL,
    gWeatherSourceName IN WEATHERSOURCE.Name%TYPE DEFAULT 'Dark Sky'
)
AS
    
    cResponse CLOB;
    tGeometry MDSYS.SDO_GEOMETRY;
    dDateTimeX DATE := COALESCE(gDateTimeX, SYSDATE_UTC);
    nGBRMetOfficeLocation_ID GBRMETOFFICELOCATION.ID%TYPE;
    
    vError VARCHAR2(100 BYTE);
    
BEGIN
    
    --Check if the geometry is WGS 84
    tGeometry := CASE gGeometry.SDO_SRID
        --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
        WHEN 4326 THEN gGeometry
        --if not, transform it to WGS 84
        ELSE SDO_CS.Transform
        (
            gGeometry,
            4326
        )
    END;
    
    
    IF gWeatherSourceName = 'GBR Met Office' THEN
        
        BEGIN
            
            --Check if there is a UK location served by the Met Office
            SELECT ID
            INTO nGBRMetOfficeLocation_ID
            FROM
            (
                --lowest ID at the smallest distance
                SELECT MIN(ID) KEEP (DENSE_RANK FIRST ORDER BY Distance) AS ID
                FROM
                (
                    SELECT ID,
                    SDO_NN_DISTANCE(1) AS Distance
                    FROM GBRMETOFFICELOCATION
                    WHERE SDO_NN
                    (
                        Geometry,
                        tGeometry,
                        'sdo_num_res=3',
                        1
                    ) = 'TRUE'
                )
                --within 10 kilometers
                WHERE Distance <= 10000
            )
            WHERE ID IS NOT NULL;
            
            SELECT TO_DATE
            (
                TO_CHAR(dDateTimeX, 'YYYY-MM-DD')
                || 'T'
                || CASE
                    WHEN Diff < 1.5/24 THEN '00'
                    WHEN Diff < 4.5/24 THEN '03'
                    WHEN Diff < 7.5/24 THEN '06'
                    WHEN Diff < 10.5/24 THEN '09'
                    WHEN Diff < 13.5/24 THEN '12'
                    WHEN Diff < 16.5/24 THEN '15'
                    WHEN Diff < 19.5/24 THEN '18'
                    WHEN Diff < 22.5/24 THEN '21'
                    ELSE '00'
                END
                || ':00:00Z',
                'YYYY-MM-DD"T"HH24:MI:SS"Z"'
            )
            INTO dDateTimeX
            FROM
            (
                SELECT dDateTimeX - TRUNC(dDateTimeX) AS Diff
                FROM DUAL
            );
            
            cResponse := UTL_HTTP.Request
            (
                url => 'datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/json/' || nGBRMetOfficeLocation_ID || '?res=3hourly'
                || '&time=' || TO_CHAR(dDateTimeX, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                || '&key='
                || GET_API_KEY('Met Office')
            );
            
        EXCEPTION
        --if there is no nearby forecast location
        WHEN NO_DATA_FOUND THEN
            --do nothing
            NULL;
            
        END;
        
    END IF;
    
    
    --Round to ~111 m (do this after GBR Met Office so their forecast location is found precisely)
    tGeometry.SDO_POINT.X := ROUND(tGeometry.SDO_POINT.X, 3);
    tGeometry.SDO_POINT.Y := ROUND(tGeometry.SDO_POINT.Y, 3);
    
    
    IF gWeatherSourceName = 'OpenWeatherMap'
    --OpenWeatherMap only provides current data
    AND gDateTimeX IS NULL THEN
        
        cResponse := UTL_HTTP.Request
        (
            url => 'api.openweathermap.org/data/2.5/weather?lat='
            || TRIM
            (
                TO_CHAR
                (
                    tGeometry.SDO_POINT.Y,
                    '90.999'
                )
            )
            || '&lon='
            || TRIM
            (
                TO_CHAR
                (
                    tGeometry.SDO_POINT.X,
                    '990.999'
                )
            )
            || '&appid='
            || GET_API_KEY('Open Weather Map App ID')
        );
        
    END IF;
    
    
    IF gWeatherSourceName = 'Dark Sky' THEN
        
        cResponse := BLOB_TO_CLOB
        (
            URL_TO_BLOB
            (
                gURL => 'https://api.darksky.net/forecast/' || GET_API_KEY('DarkSky') || '/' || TRIM
                (
                    TO_CHAR
                    (
                        tGeometry.SDO_POINT.Y,
                        '90.999'
                    )
                )
                || ','
                || TRIM
                (
                    TO_CHAR
                    (
                        tGeometry.SDO_POINT.X,
                        '990.999'
                    )
                )
                || CASE
                    WHEN gDateTimeX IS NULL THEN ''
                    --historic
                    ELSE ',' || TO_CHAR(dDateTimeX, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                END
                || '?units=si'
            )
        );
        
    END IF;
    
    
    IF cResponse IS NOT NULL THEN
        
        INSERT
        INTO WEATHER
        (
            WEATHERSOURCE_ID,
            DATETIMEX,
            GEOMETRY,
            JSON,
            COMMENTS
        )
        VALUES
        (
            (
                SELECT ID
                FROM WEATHERSOURCE
                WHERE Name = gWeatherSourceName
            ),
            dDateTimeX,
            tGeometry,
            cResponse,
            ''
        );
        
    END IF;
    
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
    
    POPULATE_WEATHER
    (
        tGeometry,
        --(SELECT MIN(DateTimeStart) FROM EXERCISESET WHERE Person_ID = 1 AND TRUNC(DateTimeStart) = TO_DATE('2016-08-02', 'YYYY-MM-DD') AND IsCompleted = 'T')
        TO_DATE('2016-08-02T15:15:43', 'YYYY-MM-DD"T"HH24:MI:SS')
    );
    
END;
/

SELECT JSON_QUERY
(
    JSON,
    '$.currently'
    RETURNING VARCHAR2(4000 BYTE) PRETTY
) AS JSON
FROM WEATHER
WHERE DateTimeX = TO_DATE('2016-08-02T15:15:43', 'YYYY-MM-DD"T"HH24:MI:SS');

BEGIN
    
    FOR A IN
    (
        SELECT Geometry,
        DateTimeX
        FROM
        (
            SELECT Workout_ID,
            Geometry,
            DateTimeX,
            ROW_NUMBER() OVER (PARTITION BY Workout_ID ORDER BY DateTimeX) AS RN
            FROM
            (
                SELECT A.Workout_ID,
                ADDRESS_TO_GEOMETRY(B.Address_ID) AS Geometry,
                A.DateTimeStart AS DateTimeX
                FROM EXERCISESET A
                INNER JOIN WORKOUT B
                    ON A.Workout_ID = B.ID
                WHERE A.IsCompleted = 'T'
            ) A
            WHERE NOT EXISTS
            (
                SELECT NULL
                FROM WEATHER B
                WHERE B.DateTimeX BETWEEN A.DateTimeX - (0.5/24) AND A.DateTimeX + (0.5/24)
                AND SDO_WITHIN_DISTANCE
                (
                    B.Geometry,
                    A.Geometry,
                    'distance=1000'
                ) = 'TRUE'
                AND B.WeatherSource_ID =
                (
                    SELECT ID
                    FROM WEATHERSOURCE
                    WHERE Name = 'Dark Sky'
                )
            )
        )
        WHERE RN = 1
    ) LOOP
        
        POPULATE_WEATHER
        (
            A.Geometry,
            A.DateTimeX
        );
        
        COMMIT;
        
        DBMS_LOCK.Sleep(1);
        
    END LOOP;
    
END;
/
*/