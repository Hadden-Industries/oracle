SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT COMPANIESHOUSE.Company('07862561') FROM DUAL;

--Many previous names
SELECT COMPANIESHOUSE.Company('02489169') FROM DUAL;
WITH COMPANYRESULT_ AS
(
    SELECT COMPANIESHOUSE.Company('02489169') AS Value
    FROM DUAL
),
PREVIOUSNAMES_ AS
(
    SELECT SortOrder,
    TO_DATE(Effective_From, 'YYYY-MM-DD') AS DateStart,
    TO_DATE(Ceased_On, 'YYYY-MM-DD') AS DateEnd,
    Name AS Value
    FROM COMPANYRESULT_
    INNER JOIN JSON_TABLE
    (
        COMPANYRESULT_.Value, '$.previous_company_names[*]'
        COLUMNS
        (
            sortOrder FOR ORDINALITY,
            effective_from VARCHAR2(4000 BYTE) PATH '$.effective_from',
            ceased_on VARCHAR2(4000 BYTE) PATH '$.ceased_on',
            name VARCHAR2(4000 BYTE) PATH '$.name'
        )
    )
        ON 1 = 1
)
--
SELECT ROW_NUMBER() OVER (ORDER BY DateStart) AS SortOrder,
DateStart,
DateEnd,
Value
FROM
(
    SELECT DateStart,
    DateEnd,
    Value
    FROM PREVIOUSNAMES_
    --
    UNION ALL
    --
    SELECT
    (
        SELECT MAX(DateEnd)
        FROM PREVIOUSNAMES_
    ) AS DateStart,
    NULL AS DateEnd,
    JSON_VALUE(Value, '$.company_name') AS Value
    FROM COMPANYRESULT_
);

SELECT 'GBR' AS Country_ID,
'CH' AS CompanyRegister_Code,
B.ID AS CompanyType_ID,
TO_DATE(A.Date_Of_Creation, 'YYYY-MM-DD') AS DateIncorporation,
TO_DATE(A.Date_Of_Creation, 'YYYY-MM-DD') AS DateRegistration,
A.Company_Number AS RegistrationID
FROM JSON_TABLE
(
    COMPANIESHOUSE.Company('02489169'),
    '$'
    COLUMNS
    (
        date_of_creation VARCHAR2(4000 BYTE) PATH '$.date_of_creation',
        company_number VARCHAR2(4000 BYTE) PATH '$.company_number',
        type VARCHAR2(4000 BYTE) PATH '$.type'
    )
) A
LEFT OUTER JOIN COMPANYTYPE B
    ON 'GBR' = B.Country_ID
            AND A.Type = B.Code;

--Illegal character `
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('06523974'),
    '$.company_name'
) FROM DUAL;

--Illegal character ~
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('06413833'),
    '$.company_name'
) FROM DUAL;

--Illegal character |
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('NI059553'),
    '$.company_name'
) FROM DUAL;

--Non-existent identifier
SELECT COMPANIESHOUSE.Company('ZZZ') FROM DUAL;

--Overseas company
SELECT COMPANIESHOUSE.Company('FC028965') FROM DUAL;

--Returns
SELECT COMPANIESHOUSE.Company('08133579') FROM DUAL;

--Pound signs
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('08152487'),
    '$.company_name'
) FROM DUAL;

--Accent
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('NI073139'),
    '$.company_name'
) FROM DUAL;

SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('NF004216'),
    '$.company_name'
) FROM DUAL;

--Square brackets
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('04410318'),
    '$.company_name'
) FROM DUAL;

--double quotes
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('FC015324'),
    '$.company_name'
) FROM DUAL;

--Yen sign
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('08344348'),
    '$.company_name'
) FROM DUAL;

--Euro sign
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('08464107'),
    '$.company_name'
) FROM DUAL;

--´ sign, but using grave accent instead of inverted comma
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('06904076'),
    '$.company_name'
) FROM DUAL;

--“” ’
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('08497243'),
    '$.company_name'
) FROM DUAL;

--‘ in the monthly feed, but replaced with ' in the API
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('SC449411'),
    '$.company_name'
) FROM DUAL;

--postcode has been corrected
SELECT COMPANIESHOUSE.Company('08851992') FROM DUAL;

--SICCodes_SICText#1 is 'None Supplied'
SELECT JSON_VALUE
(
    COMPANIESHOUSE.Company('FC029274'),
    '$.sic_codes'
) FROM DUAL;

SELECT Item,
SortOrder,
Title,
Address_Snippet,
Company_Status
FROM JSON_TABLE
(
    COMPANIESHOUSE.Search_Companies
    (
        'Hadden',
        10,
        20
    ), '$.items[*]'
    COLUMNS
    (
        item VARCHAR2(4000 BYTE) FORMAT JSON PATH '$',
        sortOrder FOR ORDINALITY,
        title VARCHAR2(4000 BYTE) PATH '$.title',
        address_snippet VARCHAR2(4000 BYTE) PATH '$.address_snippet',
        company_status VARCHAR2(4000 BYTE) PATH '$.company_status'
    )
);