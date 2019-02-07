SET DEFINE OFF;

CREATE OR REPLACE
PROCEDURE POPULATE_S_EARTHQUAKE
(
    gDateX IN DATE
)
AS
    
    cResponse CLOB;
    nMinimumMagnitude NUMBER := 3;
    vError VARCHAR2(100 BYTE);
    
BEGIN
    
    cResponse := BLOB_TO_CLOB
    (
        URL_TO_BLOB
        (
            gURL => 'http://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson'
            || '&starttime=' || TO_CHAR(TRUNC(gDateX), 'YYYY-MM-DD')
            || '&endtime=' || TO_CHAR(TRUNC(gDateX) + 1, 'YYYY-MM-DD')
            || '&minmagnitude=' || TO_CHAR(nMinimumMagnitude)
        )
    );
    
    IF cResponse IS NOT NULL THEN
        
        INSERT
        INTO S_EARTHQUAKE
        (
            DATEX,
            JSON,
            COMMENTS
        )
        VALUES
        (
            TRUNC(gDateX),
            cResponse,
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
    
BEGIN
    
    POPULATE_S_EARTHQUAKE
    (
        DATE'2016-01-01'
    );
    
END;
/

--Populate missing values
BEGIN
    
    FOR A IN
    (
        SELECT DateX
        FROM
        (
            SELECT TRUNC(DateTimeStart) AS DateX
            FROM EXERCISESET
            WHERE IsCompleted = 'T'
            --
            UNION
            --
            SELECT TRUNC(DateTimeStart) AS DateX
            FROM WORKOUT
            WHERE IsCompleted = 'T'
        )
        --Not in the last day
        WHERE DateX < TRUNC(SYSDATE) - 1
        AND DateX NOT IN
        (
            SELECT DateX
            FROM S_EARTHQUAKE
        )
    ) LOOP
        
        POPULATE_S_EARTHQUAKE
        (
            A.DateX
        );
        
        COMMIT;
        
        DBMS_LOCK.Sleep(1);
        
    END LOOP;
    
END;
/
*/