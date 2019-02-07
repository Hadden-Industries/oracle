SET SERVEROUTPUT ON;

CREATE OR REPLACE
VIEW V_UNLOCODE#UNLOCODEFUNCTION
AS
WITH PARSER
(
    ID,
    Input_Str,
    Head,
    Tail,
    Position
) AS
(
    SELECT ID,
    Input AS Input_Str,
    SUBSTR(Input, 1, 1) AS Head,
    SUBSTR(Input, 2) AS Tail,
    1 AS Position
    FROM
    (
        SELECT Country || ' ' || Location AS ID,
        Function AS Input
        FROM S_UNLOCODE
        WHERE Status IS NOT NULL
        AND
        (
            Change <> 'X'
            OR Change IS NULL
        )
        /*AND Country = 'OM'
        AND Location IN
        (
            'DQM',
            'TTH'
        )*/
        --FETCH FIRST 20 ROWS ONLY
    )
    --
    UNION ALL
    --
    SELECT ID,
    Tail AS Input_Str,
    CASE LENGTHB(Tail)
        WHEN 1 THEN Tail
        ELSE SUBSTRB(Tail, 1, 1)
    END AS Head,
    SUBSTRB(Tail, 2) AS Tail,
    Position + 1 AS Position
    FROM PARSER
    WHERE Tail IS NOT NULL
),
--
PARSED AS
(
    SELECT ID,
    Head
    FROM PARSER
    WHERE Head <> '-'
    /*WHERE TO_CHAR(Position) = Head
    OR
    (
        Position = 1
        AND Head IN
        (
            '0',
            '1'
        )
    )
    OR
    (
        Position = 8
        AND Head = 'B'
    )*/
)
--
SELECT DISTINCT
B.ID AS Country_ID,
SUBSTRB(A.ID, 4) AS UNLOCODE_Code,
A.Head AS UNLOCODEFunction_ID
FROM PARSED A
INNER JOIN COUNTRY AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) B
    ON SUBSTRB(A.ID, 1, 2) = B.Alpha2
WHERE SUBSTRB(A.ID, 4) IS NOT NULL
AND A.Head IS NOT NULL
WITH READ ONLY;

/*
--test
SELECT Country_ID,
UNLOCODE_Code,
UNLOCODEFunction_ID,
COUNT(*)
FROM V_UNLOCODE#UNLOCODEFUNCTION
GROUP BY Country_ID,
UNLOCODE_Code,
UNLOCODEFunction_ID
HAVING COUNT(*) > 1;

SELECT *
FROM V_UNLOCODE#UNLOCODEFUNCTION;
*/