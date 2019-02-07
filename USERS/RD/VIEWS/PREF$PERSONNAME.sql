CREATE OR REPLACE
VIEW PREF$PERSONNAME
AS
SELECT Person_ID,
GivenNames
|| CASE
    WHEN Surnames IS NOT NULL THEN ' '
    ELSE ''
END
|| Surnames AS Name,
GivenNames,
Surnames,
CASE
    WHEN INSTR(GivenNames, ' ') = 0 THEN GivenNames
    ELSE SUBSTR
    (
        GivenNames,
        1,
        INSTR(GivenNames, ' ') - 1
    )
END AS GivenName
FROM
(
    SELECT Person_ID,
    IsSurname,
    LISTAGG
    (
        CASE
            WHEN B.IsFirstLetter = 'F' THEN A.Value
            ELSE SUBSTR(A.Value, 1, 1)
        END,
        ' '
    ) WITHIN GROUP (ORDER BY SortOrder) AS Value
    FROM
    (
        SELECT ID,
        Person_ID,
        IsSurname,
        SortOrder,
        Value,
        Phonetic,
        DateStart,
        DateEnd,
        DateTimeCreated,
        DateTimeDeleted,
        Comments
        FROM PERSONNAME AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) A
        --emulate AS OF PERIOD FOR TRANSACTION_TIME SYSDATE_UTC
        WHERE DateTimeCreated <= SYS_EXTRACT_UTC(SYSTIMESTAMP)
        AND
        (
            DateTimeDeleted IS NULL
            OR
            DateTimeDeleted > SYS_EXTRACT_UTC(SYSTIMESTAMP)
        )

    ) A
    INNER JOIN PERSONNAMEPREFERENCE AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) B
        ON A.ID = B.PersonName_ID
    WHERE B.DateTimeCreated <= SYSDATE_UTC
    AND
    (
        B.DateTimeDeleted IS NULL
        OR
        B.DateTimeDeleted > SYSDATE_UTC
    )
    GROUP BY Person_ID,
    IsSurname
)
PIVOT
(
    MIN(Value)
    FOR IsSurname IN
    (
        'T' AS Surnames,
        'F' AS GivenNames
    )
)
WITH READ ONLY;

/*
--test
SELECT Person_ID,
COUNT(*)
FROM PREF$PERSONNAME
GROUP BY Person_ID
HAVING COUNT(*) > 1
;

SELECT *
FROM PREF$PERSONNAME
WHERE Person_ID = 10
;
*/