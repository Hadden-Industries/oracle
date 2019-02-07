SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
FUNCTION GET_LOCATION
(
    gDateTimeX IN DATE,
    gPerson IN VARCHAR2 DEFAULT 1
)
RETURN SDO_GEOMETRY
DETERMINISTIC
PARALLEL_ENABLE
AS
    
    nPerson_ID PERSON.ID%TYPE;
    lGeometry SDO_GEOMETRY;
    
BEGIN
    
    --DBMS_OUTPUT.Enable;
    
    IF VALIDATE_CONVERSION(gPerson AS NUMBER) = 1 THEN
        
        SELECT ID
        INTO nPerson_ID
        FROM PERSON
        WHERE ID = gPerson;
        
    ELSE
        
        SELECT Person_ID
        INTO nPerson_ID
        FROM PREF$PERSONNAME
        WHERE Name = gPerson;
        
    END IF;
    
    --DBMS_OUTPUT.Put_Line(TO_CHAR(nPerson_ID));
    
    BEGIN
        
        SELECT Geometry
        INTO lGeometry
        FROM
        (
            SELECT CAST(D.DateTimeStart AT TIME ZONE 'UTC' AS DATE) AS DateTimeX,
            E.Geometry,
            ROW_NUMBER() OVER (ORDER BY ABS(gDateTimeX - CAST(D.DateTimeStart AT TIME ZONE 'UTC' AS DATE))) AS RN
            FROM NATURALPERSON A
            INNER JOIN EVENT#OBJECT B
                ON A.Object_ID = B.Object_ID
            INNER JOIN EVENTTOOBJECTTYPE C
                ON B.EventToObjectType_ID = C.ID
            INNER JOIN EVENT D
                ON B.Event_ID = D.ID
            INNER JOIN LOCATION E
                ON D.Location_ID = E.ID
            WHERE A.Person_ID = nPerson_ID
            AND C.Name = 'Located Object'
            AND D.DateTimeStart BETWEEN FROM_TZ(CAST(gDateTimeX - (3 * 60)/(24 * 60 * 60) AS TIMESTAMP), 'UTC') AND FROM_TZ(CAST(gDateTimeX + (3 * 60)/(24 * 60 * 60) AS TIMESTAMP), 'UTC')
        )
        WHERE RN = 1;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        RETURN NULL;
        
    END;
    
    RETURN lGeometry;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT A.Geometry.SDO_POINT.Y AS Latitude,
A.Geometry.SDO_POINT.X AS Longitude,
A.Geometry.SDO_POINT.Z AS Altitude
FROM
(
    SELECT GET_LOCATION
    (
        TO_DATE('2014-09-10T08:20:53', 'YYYY-MM-DD"T"HH24:MI:SS'),
        'Max Shostak'
    ) AS Geometry
    FROM DUAL
) A;


--TODO Extrapolate
SELECT Person_ID,
DateTimeX,
Geometry,
Inter,
TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') - MIN(CASE
    WHEN Inter < 0 THEN NULL
    ELSE Inter
END) OVER () AS Min$DateTimeX,
TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') + MIN
(
    CASE
        WHEN Inter > 0 THEN NULL
        ELSE -Inter
    END
) OVER () AS Max$DateTimeX
FROM
(
    SELECT Person_ID,
    DateTimeX,
    Geometry,
    TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') - DateTimeX AS Inter,
    ROW_NUMBER() OVER (ORDER BY ABS(TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') - DateTimeX)) AS RN
    FROM PERSONLOCATION
    WHERE Person_ID = 1
    AND DateTimeX BETWEEN TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') - (5 * 60)/(24 * 60 * 60) AND TO_DATE('2014-09-10T08:20:54', 'YYYY-MM-DD"T"HH24:MI:SS') + (5 * 60)/(24 * 60 * 60)
)
ORDER BY Inter;
*/