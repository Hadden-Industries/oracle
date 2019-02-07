CREATE OR REPLACE
VIEW LATEST$INBOUND
(
    URL,
    DATETIMEX,
    TABLELOOKUP_NAME,
    DATA,
    COMMENTS,
    CONSTRAINT LATEST$INBOUND_PK PRIMARY KEY (URL) RELY DISABLE
)
--
AS
SELECT URL,
DateTimeX,
TableLookup_Name,
Data,
Comments
FROM
(
    SELECT URL,
    DateTimeX,
    TableLookup_Name,
    Data,
    Comments,
    ROW_NUMBER() OVER (PARTITION BY URL ORDER BY DateTimeX DESC) AS RN
    FROM INBOUND
)
WHERE RN = 1
WITH READ ONLY;

/*
--test
SELECT *
FROM LATEST$INBOUND
WHERE URL = 'http://download.geonames.org/export/dump/admin1CodesASCII.txt';
*/