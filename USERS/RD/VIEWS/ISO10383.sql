CREATE OR REPLACE
VIEW ISO10383
(
    DATETIMEGENERATED,
    COUNTRY_NAME,
    COUNTRY_ALPHA2 ,
    ID,
    PARENT$ISO10383_ID,
    OS,
    NAME,
    ACRONYM,
    TOWNNAME,
    URL,
    DATEMODIFIED,
    STATUS,
    DATESTART,
    COMMENTS,
    CONSTRAINT ISO10383_PK PRIMARY KEY (ID) RELY DISABLE
)
AS
SELECT DateTimeGenerated,
CAST
(
    SINGLE_LINE(Country_Name) AS VARCHAR2(255 CHAR)
) AS Country_Name,
CAST
(
    SINGLE_LINE
    (
        CASE Country_Alpha2
            --Really?
            WHEN 'N/A' THEN 'ZZ'
            ELSE Country_Alpha2
        END
    ) AS CHAR(2 BYTE)
) AS Country_Alpha2,
CAST
(
    CASE
        WHEN REGEXP_LIKE
        (
            SINGLE_LINE(ID),
            '^([A-Z0-9]{4})$'
        ) THEN SINGLE_LINE(ID)
        ELSE NULL
    END AS CHAR(4 BYTE)
) AS ID,
CAST
(
    CASE
        WHEN REGEXP_LIKE
        (
            SINGLE_LINE(Parent$ISO10383_ID),
            '^([A-Z0-9]{4})$'
        ) THEN SINGLE_LINE(Parent$ISO10383_ID)
        ELSE NULL
    END AS CHAR(4 BYTE)
) AS Parent$ISO10383_ID,
CAST
(
    CASE
        WHEN OS IN ('O', 'S') THEN OS
        ELSE NULL
    END AS CHAR(1 BYTE)
) AS OS,
CAST
(
    SINGLE_LINE(Name) AS VARCHAR2(255 CHAR)
) AS Name,
CAST
(
    SINGLE_LINE(Acronym) AS VARCHAR2(255 CHAR)
) AS Acronym,
CAST
(
    SINGLE_LINE
    (
        CASE TownName
            WHEN 'ZZ' THEN NULL
            ELSE TownName
        END
    ) AS VARCHAR2(255 CHAR)
) AS TownName,
CAST
(
    LOWER
    (
        SINGLE_LINE
        (
            CASE URL
                WHEN 'ZZ' THEN NULL
                ELSE URL
            END
        )
    ) AS VARCHAR2(255 CHAR)
) AS URL,
CAST
(
    SINGLE_LINE(DateModified) AS VARCHAR2(255 CHAR)
) AS DateModified,
CAST
(
    SINGLE_LINE(Status) AS VARCHAR2(255 CHAR)
) AS Status,
CAST
(
    SINGLE_LINE(DateStart) AS VARCHAR2(255 CHAR)
) AS DateStart,
CAST
(
    SINGLE_LINE(Comments) AS VARCHAR2(255 CHAR)
) AS Comments
FROM XMLTABLE
(
    '/dataroot/MICs_x0020_List_x0020_by_x0020_Country' PASSING XMLTYPE
    (
        BFileName('RD', 'ISO10383_MIC.xml'),
        NLS_CHARSET_ID('AL32UTF8')
    )
    RETURNING SEQUENCE BY REF
    COLUMNS DateTimeGenerated TIMESTAMP(0) PATH '../@generated',
    Country_Name VARCHAR2(255 CHAR) PATH 'COUNTRY',
    Country_Alpha2 CHAR(2 BYTE) PATH 'ISO_x0020_COUNTRY_x0020_CODE_x0020__x0028_ISO_x0020_3166_x0029_',
    ID VARCHAR2(255 CHAR) PATH 'MIC',
    Parent$ISO10383_ID VARCHAR2(255 CHAR) PATH 'OPERATING_x0020_MIC',
    OS CHAR(1 BYTE) PATH 'O_x002F_S',
    Name VARCHAR2(255 CHAR) PATH 'NAME-INSTITUTION_x0020_DESCRIPTION',
    Acronym VARCHAR2(255 CHAR) PATH 'ACRONYM',
    TownName VARCHAR2(255 CHAR) PATH 'CITY',
    URL VARCHAR2(255 CHAR) PATH 'WEBSITE',
    DateModified VARCHAR2(255 CHAR) PATH 'STATUS_x0020_DATE',
    Status VARCHAR2(255 CHAR) PATH 'STATUS',
    DateStart VARCHAR2(255 CHAR) PATH 'CREATION_x0020_DATE',
    Comments VARCHAR2(255 CHAR) PATH 'COMMENTS'
)
WITH READ ONLY;

/*
--test
SELECT *
FROM ISO10383;

--De-activations
SELECT *
FROM MARKET
WHERE
(
    DateEnd IS NULL
    OR TRUNC(SYSDATE_UTC) < DateEnd
)
AND ID NOT IN
(
    SELECT ID
    FROM ISO10383
);
*/