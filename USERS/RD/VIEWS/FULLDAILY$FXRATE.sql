CREATE OR REPLACE
VIEW FULLDAILY$FXRATE
AS
--Base rates
SELECT From$Currency_ID,
To$Currency_ID,
DateX,
Rate
FROM UNIQUE$FXRATE
--Inverses
UNION ALL
--
SELECT To$Currency_ID AS From$Currency_ID,
From$Currency_ID AS To$Currency_ID,
DateX,
(1/Rate) AS Rate
FROM UNIQUE$FXRATE
--Cross rates
UNION ALL
--
SELECT A.To$Currency_ID AS From$Currency_ID,
B.To$Currency_ID AS To$Currency_ID,
A.DateX,
(B.Rate/A.Rate) AS Rate
FROM UNIQUE$FXRATE A
INNER JOIN UNIQUE$FXRATE B
    ON A.From$Currency_ID = B.From$Currency_ID
            AND A.To$Currency_ID <> B.To$Currency_ID
            AND A.DateX = B.DateX
/*--Weekend rates as being the ones from Friday if from ECB mid rates
UNION ALL
--
SELECT A.From$Currency_ID,
A.To$Currency_ID,
A.DateX + B.DaysAdded,
A.FXRateType_ID,
A.Rate
FROM FXRATE A
INNER JOIN
(
    SELECT 1 AS One,
    1 AS DaysAdded
    FROM DUAL
    --
    UNION ALL
    --
    SELECT 1 One,
    2 AS DaysAdded
    FROM DUAL
) B
    ON 1 = B.One
--The Mid rates are only given by the ECB and these are working day only
WHERE A.FXRateType_ID =
(
    SELECT ID
    FROM FXRATETYPE
    WHERE Name = 'Mid'
)
AND TO_CHAR(A.DateX, 'DY') = 'FRI'*/
--Equalities
UNION ALL
--
SELECT B.ID AS From$Currency_ID,
B.ID AS To$Currency_ID,
A.DateX,
1 AS Rate
FROM
(
    SELECT (DateFrom + LEVEL - 1) AS DateX
    FROM
    (
        SELECT
        (
            SELECT MIN(DateX)
            FROM UNIQUE$FXRATE
        ) AS DateFrom,
        TRUNC(SYSDATE) AS DateTo
        FROM DUAL
    )
    CONNECT BY LEVEL <= (DateTo - DateFrom + 1)
) A
INNER JOIN CURRENCY B
    ON A.DateX BETWEEN COALESCE(B.DateStart, TO_DATE('0001-01-01', 'YYYY-MM-DD')) AND COALESCE(B.DateEnd, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
WITH READ ONLY;