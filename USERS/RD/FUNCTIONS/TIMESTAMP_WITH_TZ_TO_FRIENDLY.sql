CREATE OR REPLACE
FUNCTION TIMESTAMP_WITH_TZ_TO_FRIENDLY
(
    gTimeStamp_With_TZ IN TIMESTAMP WITH TIME ZONE
)
RETURN VARCHAR2
PARALLEL_ENABLE
AS

    PRAGMA UDF;
    vTimeZone_Region VARCHAR2(32 BYTE) := EXTRACT(TIMEZONE_REGION FROM gTimeStamp_With_TZ);
    dTimeStampCurrentLocal TIMESTAMP WITH TIME ZONE := SYSTIMESTAMP AT TIME ZONE vTimeZone_Region;

BEGIN

    IF (EXTRACT(DAY FROM dTimeStampCurrentLocal - gTimeStamp_With_TZ) <= 0) THEN

        RETURN DSINTERVAL_TO_FRIENDLY
        (
            dTimeStampCurrentLocal - gTimeStamp_With_TZ,
            'minute'
        );

    ELSE
        
        RETURN CASE
            WHEN gTimeStamp_With_TZ >= TRUNC(dTimeStampCurrentLocal) - 1 THEN 'Yesterday ' || TO_CHAR(gTimeStamp_With_TZ, 'HH24:MI')
            WHEN gTimeStamp_With_TZ >= TRUNC(dTimeStampCurrentLocal) - 6 THEN TO_CHAR(gTimeStamp_With_TZ, 'fmDay ') || TO_CHAR(gTimeStamp_With_TZ, 'HH24:MI')
            WHEN gTimeStamp_With_TZ >= TRUNC(ADD_MONTHS(dTimeStampCurrentLocal, -11), 'MM') THEN TO_CHAR(gTimeStamp_With_TZ, 'Dy fmDD Mon, ') || TO_CHAR(gTimeStamp_With_TZ, 'HH24:MI')
            ELSE TO_CHAR(gTimeStamp_With_TZ, 'DD Mon YYYY, HH24:MI')
        END;

    END IF;

END;
/

/*
--test
SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(2, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(-1, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(-3, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(-7, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(-32, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);

SELECT TimeStampWithTimeZone,
TIMESTAMP_WITH_TZ_TO_FRIENDLY(TimeStampWithTimeZone)
FROM
(
    SELECT SYS_EXTRACT_UTC(SYSTIMESTAMP) AT TIME ZONE 'EUROPE/LONDON' + NUMTODSINTERVAL(-600, 'DAY') AS TimeStampWithTimeZone
    FROM DUAL
);
*/