CREATE OR REPLACE
VIEW S_ISO4217
AS
SELECT SINGLE_LINE(Entity) AS Entity,
SINGLE_LINE(Name) AS Name,
SINGLE_LINE(ID) AS ID,
CASE
    WHEN REGEXP_LIKE
    (
        SINGLE_LINE(NumericCode),
        '^([[:digit:]]{3})$'
    ) THEN SINGLE_LINE(NumericCode)
    ELSE NULL
END AS NumericCode,
CASE
    WHEN VALIDATE_CONVERSION
    (
        SINGLE_LINE(MinorUnit) AS NUMBER
    ) = 1 THEN TO_NUMBER
    (
        SINGLE_LINE(MinorUnit)
    )
    ELSE NULL
END AS MinorUnit,
DateEnd,
SINGLE_LINE(Comments) AS Comments,
CASE
    WHEN Fund = 'true' THEN 'T'
    ELSE 'F'
END AS Fund
FROM
(
    SELECT S_ISO4217_CURRENT.Entity,
    S_ISO4217_CURRENT.Currency AS Name,
    S_ISO4217_CURRENT.Alphabetic_Code AS ID,
    S_ISO4217_CURRENT.Numeric_Code AS NumericCode,
    S_ISO4217_CURRENT.Minor_unit AS MinorUnit,
    S_ISO4217_CURRENT.Withdrawal_Date AS DateEnd,
    S_ISO4217_CURRENT.Remark AS Comments,
    S_ISO4217_CURRENT.IsFund AS Fund
    FROM LATEST$INBOUND X
    INNER JOIN XMLTABLE
    (
        '/ISO_4217/CcyTbl/CcyNtry' PASSING XMLPARSE(DOCUMENT X.Data)
        COLUMNS ENTITY VARCHAR2(140 CHAR) PATH 'CtryNm',
        CURRENCY VARCHAR2(140 CHAR) PATH 'CcyNm',
        ISFUND VARCHAR2(5 CHAR) PATH 'CcyNm/@IsFund',
        ALPHABETIC_CODE VARCHAR2(3 CHAR) PATH 'Ccy',
        NUMERIC_CODE VARCHAR2(3 BYTE) PATH 'CcyNbr',
        WITHDRAWAL_DATE VARCHAR2(140 CHAR) PATH 'WthdrwlDt',
        MINOR_UNIT VARCHAR2(4 BYTE) PATH 'CcyMnrUnts',
        REMARK VARCHAR2(140 CHAR) PATH 'AddtlInf'
    ) AS S_ISO4217_CURRENT
        ON 1 = 1
    WHERE X.TableLookup_Name = 'CURRENCY'
    AND X.URL LIKE '%/list_one.xml'
    --
    UNION ALL
    --
    SELECT S_ISO4217_HISTORIC.Entity,
    S_ISO4217_HISTORIC.Currency AS Name,
    S_ISO4217_HISTORIC.Alphabetic_Code AS ID,
    S_ISO4217_HISTORIC.Numeric_Code AS NumericCode,
    S_ISO4217_HISTORIC.Minor_unit AS MinorUnit,
    S_ISO4217_HISTORIC.Withdrawal_Date AS DateEnd,
    S_ISO4217_HISTORIC.Remark AS Comments,
    S_ISO4217_HISTORIC.IsFund AS Fund
    FROM LATEST$INBOUND X
    INNER JOIN XMLTABLE
    (
        '/ISO_4217/HstrcCcyTbl/HstrcCcyNtry' PASSING XMLPARSE(DOCUMENT X.Data)
        COLUMNS ENTITY VARCHAR2(140 CHAR) PATH 'CtryNm',
        CURRENCY VARCHAR2(140 CHAR) PATH 'CcyNm',
        ISFUND VARCHAR2(5 CHAR) PATH 'CcyNm/@IsFund',
        ALPHABETIC_CODE VARCHAR2(3 CHAR) PATH 'Ccy',
        NUMERIC_CODE VARCHAR2(3 BYTE) PATH 'CcyNbr',
        WITHDRAWAL_DATE VARCHAR2(140 CHAR) PATH 'WthdrwlDt',
        MINOR_UNIT VARCHAR2(4 BYTE) PATH 'CcyMnrUnts',
        REMARK VARCHAR2(140 CHAR) PATH 'AddtlInf'
    ) AS S_ISO4217_HISTORIC
        ON 0 = 0
    WHERE X.TableLookup_Name = 'CURRENCY'
    AND X.URL LIKE '%/list_three.xml'
)
WITH READ ONLY;

/*
--test
SELECT *
FROM S_ISO4217
WHERE Fund = 'T';
*/