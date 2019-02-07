CREATE OR REPLACE
FUNCTION DSINTERVAL_TO_DURATION
(
    gInterval IN INTERVAL DAY TO SECOND,
    gTrunc IN VARCHAR2 DEFAULT 'second'
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
            WHEN Day_ > 0 OR Hour_ > 0 OR Minute_ > 0 OR Second_ > 0 THEN 'P'
            || CASE
                WHEN Day_ > 0 THEN TO_CHAR(Day_) || 'D'
                ELSE ''
            END
            || CASE
                WHEN Hour_ > 0 OR Minute_ > 0 OR Second_ > 0 THEN 'T'
                ELSE ''
            END
            || CASE
                WHEN Hour_ > 0 AND gTrunc >= 'hour' THEN TO_CHAR(Hour_) || 'H'
                ELSE ''
            END
            || CASE
                WHEN Minute_ > 0 AND gTrunc >= 'minute' THEN TO_CHAR(Minute_) || 'M'
                ELSE ''
            END
            || CASE
                WHEN Second_ > 0 AND gTrunc >= 'second' THEN TO_CHAR(Second_) || 'S'
                ELSE ''
            END
            ELSE ''
        END
        INTO vReturn
        FROM
        (
            SELECT EXTRACT(DAY FROM iInterval) AS Day_,
            EXTRACT(HOUR FROM iInterval) AS Hour_,
            EXTRACT(MINUTE FROM iInterval) AS Minute_,
            ROUND(EXTRACT(SECOND FROM iInterval)) AS Second_
            FROM DUAL
        );

    RETURN vReturn;

END;
/

/*
--test
SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('-0 0:0:0.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('10 3:0:1.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('10 3:0:1.000'), 'minute')
FROM DUAL
;

SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('0 3:55:1.000'))
FROM DUAL
;

SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('-0 3:55:1.000'))
FROM DUAL
;

--test rounding
SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('0 3:55:31.000'), 'minute')
FROM DUAL
;

--incorrectly gave "now"
SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('+00 00:59:59.000000'), 'minute') Min
FROM DUAL
;

--incorrectly gave 0.99 seconds
SELECT DSINTERVAL_TO_DURATION(TO_DSINTERVAL('+00 00:00:00.990000'), 'second') AS Sec
FROM DUAL
;

SELECT DSINTERVAL_TO_DURATION
(
    gInterval=>CAST(DateTimeEnd AS TIMESTAMP) - CAST(DateTimeStart AS TIMESTAMP),
    gTrunc=>'minute'
)
FROM JYM$WORKOUT
WHERE ID = 153
;
*/