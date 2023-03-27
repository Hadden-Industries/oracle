CREATE OR REPLACE
VIEW S_GBRONSRGC
AS
SELECT ID,
Name,
Abbreviation,
Theme,
Coverage,
Related_S_GBRONSRGCID,
Status,
CAST
(
    REPLACE(NumberLive, ',')
    AS INTEGER
    DEFAULT NULL ON CONVERSION ERROR
) AS NumberLive,
CAST
(
    REPLACE(NumberArchived, ',')
    AS INTEGER
    DEFAULT NULL ON CONVERSION ERROR
) AS NumberArchived,
COALESCE
(
    CAST
    (
        REPLACE(NumberCrossBorder, ',')
        AS INTEGER
        DEFAULT NULL ON CONVERSION ERROR
    ),
    0
) AS NumberCrossBorder,
CASE
    WHEN DateUpdated = 'n/a' THEN NULL
    --ORA-43909: invalid input data type in 18c
    --WHEN /*VALIDATE_CONVERSION(DateUpdated AS DATE, 'DD/MM/YYYY')*/1 = 1 THEN TO_DATE(DateUpdated, 'DD/MM/YYYY')
    ELSE CAST(DateUpdated AS DATE DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY')
END AS DateUpdated,
First_CHD_ID,
Last_CHD_ID,
Reserved_CHD_ID,
Owner,
CAST(DateAdded AS DATE DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY') AS DateAdded,
CAST(DateStart AS DATE DEFAULT NULL ON CONVERSION ERROR, 'DD/MM/YYYY') AS DateStart
FROM
(
    SELECT Row_Nr AS RN,
    Col_Nr,
    COALESCE
    (
        TO_CHAR(Date_Val, 'DD/MM/YYYY'),
        TO_CHAR(Number_Val),
        DBMS_LOB.SUBSTR(String_Val, 4000, 1)
    ) AS String_Val
    FROM TABLE
    (
        AS_READ_XLSX.Read
        (
            --ORA-31186: Document contains too many nodes
            /*ZIP.Get_File
            (
                FILE_TO_BLOB('Register_of_Geographic_Codes_(April_2018)_UK.zip'),
                'RGC_APR_2018_UK.xlsx'
            )*/
            AS_READ_XLSX.File2BLOB
            (
                'RD',
                'S_GBRONSRGC.xlsx'
            ),
            'RGC'
        )
    )
)
PIVOT
(
    MIN(String_Val)
    FOR Col_Nr IN
    (
        1 AS ID,
        2 AS Name,
        3 AS Abbreviation,
        4 AS Theme,
        5 AS Coverage,
        6 AS Related_S_GBRONSRGCID,
        7 AS Status,
        8 AS NumberLive,
        9 AS NumberArchived,
        10 AS NumberCrossBorder,
        11 AS DateUpdated,
        12 AS First_CHD_ID,
        13 AS Last_CHD_ID,
        14 AS Reserved_CHD_ID,
        15 AS Owner,
        16 AS DateAdded,
        17 AS DateStart
    )
)
--Ignore the header
--WHERE RN > 1
--Empty rows here
--AND REGEXP_LIKE(ID, '^([A-Z]{1}[[:digit:]]{2})$')
WITH READ ONLY;