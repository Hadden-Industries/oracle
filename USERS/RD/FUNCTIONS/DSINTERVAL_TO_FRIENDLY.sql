CREATE OR REPLACE
FUNCTION DSINTERVAL_TO_FRIENDLY
(
    gInterval IN INTERVAL DAY TO SECOND,
    gTrunc IN VARCHAR2 DEFAULT 'second',
    gSuppressQualifier IN INTEGER DEFAULT 0,
    gAbbreviations IN INTEGER DEFAULT 0
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS

    PRAGMA UDF;

    iInterval INTERVAL DAY TO SECOND := gInterval + CASE gTrunc
        WHEN 'day' THEN CASE
            WHEN EXTRACT(HOUR FROM gInterval) BETWEEN 12 AND 23 THEN NUMTODSINTERVAL(1, 'DAY')
            WHEN EXTRACT(HOUR FROM gInterval) BETWEEN 0 AND 12 THEN NUMTODSINTERVAL(-1, 'DAY')
            ELSE INTERVAL '0' DAY
        END
        WHEN 'hour' THEN CASE
            WHEN EXTRACT(MINUTE FROM gInterval) BETWEEN 30 AND 59 THEN NUMTODSINTERVAL(1, 'HOUR')
            WHEN EXTRACT(MINUTE FROM gInterval) BETWEEN -59 AND -30 THEN NUMTODSINTERVAL(-1, 'HOUR')
            ELSE INTERVAL '0' HOUR
        END
        WHEN 'minute' THEN CASE
            WHEN EXTRACT(SECOND FROM gInterval) BETWEEN 30 AND 59 THEN NUMTODSINTERVAL(1, 'MINUTE')
            WHEN EXTRACT(SECOND FROM gInterval) BETWEEN -59 AND -30 THEN NUMTODSINTERVAL(-1, 'MINUTE')
            ELSE INTERVAL '0' MINUTE
        END
        ELSE INTERVAL '0' SECOND
    END;
    vReturn VARCHAR2(4000 BYTE) := '';

BEGIN

    SELECT CASE 
        WHEN Text IS NULL THEN 'now'
        WHEN gSuppressQualifier = 0 THEN CASE
            WHEN IsPast = 1 THEN Text || ' ago'
            ELSE 'in ' || Text
        END
        ELSE Text
    END AS Text
    INTO vReturn
    FROM
    (
        SELECT LISTAGG
        (
            TO_CHAR
            (
                ABS(Value)
            ) || ' '
            || Type
            || CASE
                WHEN ABS(Value) > 1 THEN 's'
                ELSE NULL
            END,
            ', '
        ) WITHIN GROUP (ORDER BY Type) AS Text,
        CASE
            WHEN MIN(Value) > 0 THEN 1
            ELSE 0
        END AS IsPast
        FROM
        (
            SELECT Type,
            Value
            FROM
            (
                SELECT EXTRACT(DAY FROM iInterval) AS nDay,
                EXTRACT(HOUR FROM iInterval) AS nHour,
                EXTRACT(MINUTE FROM iInterval) AS nMinute,
                ROUND(EXTRACT(SECOND FROM iInterval)) AS nSecond
                FROM DUAL
            )
            UNPIVOT
            (
                Value
                FOR Type IN
                (
                    nDay AS 'day',
                    nHour AS 'hour',
                    nMinute AS 'minute',
                    nSecond AS 'second'
                )
            )
            WHERE Value != 0
            AND Type <= gTrunc
        )
    );

    RETURN vReturn;

END;
/

/*
--test
SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('-0 0:0:0.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('10 3:0:1.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('10 3:0:1.000'), 'minute')
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('0 3:55:1.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('-0 3:55:1.000'))
FROM DUAL
;

--test rounding
SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('-0 3:55:31.000'), 'minute')
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('0 3:55:31.000'), 'minute')
FROM DUAL
;
--incorrectly gave "now"
SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('+00 00:59:59.000000'), 'minute') Min
FROM DUAL
;

--incorrectly gave 0.99 seconds
SELECT DSINTERVAL_TO_FRIENDLY(TO_DSINTERVAL('+00 00:00:00.990000'), 'second') AS Sec
FROM DUAL
;

SELECT DSINTERVAL_TO_FRIENDLY
(
    gInterval=>CAST(DateTimeEnd AS TIMESTAMP) - CAST(DateTimeStart AS TIMESTAMP),
    gTrunc=>'minute',
    gSuppressQualifier=>1
)
FROM JYM$WORKOUT
WHERE ID = 153
;
*/