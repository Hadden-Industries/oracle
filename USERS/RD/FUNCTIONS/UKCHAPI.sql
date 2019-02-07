SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
FUNCTION UKCHAPI
(
    gRegistrationID IN VARCHAR2,
    gFieldNames IN VARCHAR2
)
RETURN SPLIT_TABLE PIPELINED
AS
    
    --Program variables
    bData BLOB;
    req UTL_HTTP.REQ;
    resp UTL_HTTP.RESP;
    rResp RAW(1000);
    rSPLIT_TYPE SPLIT_TYPE := SPLIT_TYPE(gRegistrationID, 0, NULL);
    vProxy VARCHAR2(32767 BYTE) := '';
    xData XMLTYPE;
    
    --Error variable
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN

    DBMS_LOB.CreateTemporary
    (
        lob_loc => bData,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open
    (
        bData,
        DBMS_LOB.LOB_READWRITE
    );
    
    BEGIN
        
        SELECT 'http://' || IPV4 || ':' || Port
        INTO vProxy
        FROM PROXY
        WHERE IPV4 IS NOT NULL
        AND Port IS NOT NULL;
        
        UTL_HTTP.Set_Proxy(vProxy, NULL);
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    req := UTL_HTTP.Begin_Request
    (
        url => 'http://data.companieshouse.gov.uk/doc/company/' || gRegistrationID || '.xml',
        method => 'GET'
    );
    
    UTL_HTTP.Set_Header
    (
        r => req,
        name => 'Content-Type',
        value => 'application/x-www-form-urlencoded'
    );
    
    resp := UTL_HTTP.Get_Response(req);
    
    IF resp.Status_Code != 200 THEN
        
        UTL_HTTP.End_Response(resp);
        
        IF DBMS_LOB.GetLength(bData) > 0 THEN
            
            DBMS_LOB.Close(bData);
            
            DBMS_LOB.FreeTemporary(bData);
            
        END IF;
        
        RAISE NO_DATA_FOUND;
        
    END IF;
    
    BEGIN
        
        LOOP
            
            UTL_HTTP.Read_Raw(resp, rResp, 1000);
            
            DBMS_LOB.WriteAppend(bData, UTL_RAW.Length(rResp), TO_BLOB(rResp));
            
        END LOOP;
        
        UTL_HTTP.End_Response(resp);
        
    EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
        
        UTL_HTTP.End_Response(resp);
        
    WHEN OTHERS THEN
        
        vError := SUBSTRB(SQLErrM, 1, 255);
        
        DBMS_OUTPUT.Put_Line(vError);
        
        UTL_HTTP.End_Response(resp);
        
        IF DBMS_LOB.GetLength(bData) > 0 THEN
            
            DBMS_LOB.Close(bData);
            
            DBMS_LOB.FreeTemporary(bData);
            
        END IF;
        
        RAISE NO_DATA_FOUND;
        
    END;
    
    SELECT XMLPARSE
    (
        DOCUMENT BLOB_TO_CLOB(bData, 'WE8ISO8859P1')
        WELLFORMED
    )
    INTO xData
    FROM DUAL;
    
    FOR C IN
    (
        SELECT B.Position,
        A.Value
        FROM
        (
            SELECT FieldName,
            Value
            FROM
            (
                SELECT REPLACE
                (
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE
                            (
                                REPLACE
                                (
                                    A.CompanyName,
                                    'â¬',
                                    '€'
                                ),
                                'â',
                                '’'
                            ),
                            'â',
                            '‘'
                        ),
                        'â',
                        '“'
                    ),
                    'â',
                    '”'
                ) AS CompanyName,
                A.CompanyNumber,
                A.RegAddress_CareofName,
                A.RegAddress_PoBox,
                A.RegAddress_AddressLine1,
                A.RegAddress_AddressLine2,
                A.RegAddress_PostTown,
                A.RegAddress_County,
                A.RegAddress_Country,
                A.RegAddress_Postcode,
                A.CompanyCategory,
                A.CompanyStatus,
                A.CountryOfOrigin,
                A.DissolutionDate,
                A.IncorporationDate,
                A.RegistrationDate,
                A.Accounts_AccountRefDay,
                A.Accounts_AccountRefMonth,
                A.Accounts_NextDueDate,
                A.Accounts_LastMadeUpDate,
                A.Accounts_AccountCategory,
                A.Returns_NextDueDate,
                A.Returns_LastMadeUpDate,
                A.Mortgages_NumMortCharges,
                A.Mortgages_NumMortOutstanding,
                A.Mortgages_NumMortPartSatisfied,
                A.Mortgages_NumMortSatisfied,
                TRIM
                (
                    BOTH CHR(10)
                    FROM TRIM(B.SICCodes_SicText#1)
                ) AS SICCodes_SicText#1,
                TRIM
                (
                    BOTH CHR(10)
                    FROM TRIM(B.SICCodes_SicText#2)
                ) AS SICCodes_SicText#2,
                TRIM
                (
                    BOTH CHR(10)
                    FROM TRIM(B.SICCodes_SicText#3)
                ) AS SICCodes_SicText#3,
                TRIM
                (
                    BOTH CHR(10)
                    FROM TRIM(B.SICCodes_SicText#4)
                ) AS SICCodes_SicText#4,
                A.LimitedPartnerships_NumGenPart,
                A.LimitedPartnerships_NumLimPart
                FROM XMLTABLE
                (
                    XMLNAMESPACES(DEFAULT 'http://www.companieshouse.gov.uk/terms/xxx'),
                    '/Result/primaryTopic'
                    PASSING xData
                    COLUMNS
                    CompanyName VARCHAR2(4000 BYTE) PATH 'CompanyName',
                    CompanyNumber VARCHAR2(4000 BYTE) PATH 'CompanyNumber',
                    RegAddress_CareofName VARCHAR2(4000 BYTE) PATH 'RegAddress/CareofName',
                    RegAddress_PoBox VARCHAR2(4000 BYTE) PATH 'RegAddress/PoBox',
                    RegAddress_AddressLine1 VARCHAR2(4000 BYTE) PATH 'RegAddress/AddressLine1',
                    RegAddress_AddressLine2 VARCHAR2(4000 BYTE) PATH 'RegAddress/AddressLine2',
                    RegAddress_PostTown VARCHAR2(4000 BYTE) PATH 'RegAddress/PostTown',
                    RegAddress_County VARCHAR2(4000 BYTE) PATH 'RegAddress/County',
                    RegAddress_Country VARCHAR2(4000 BYTE) PATH 'RegAddress/Country',
                    RegAddress_Postcode VARCHAR2(4000 BYTE) PATH 'RegAddress/Postcode',
                    CompanyCategory VARCHAR2(4000 BYTE) PATH 'CompanyCategory',
                    CompanyStatus VARCHAR2(4000 BYTE) PATH 'CompanyStatus',
                    CountryOfOrigin VARCHAR2(4000 BYTE) PATH 'CountryOfOrigin',
                    DissolutionDate VARCHAR2(4000 BYTE) PATH 'DissolutionDate',
                    IncorporationDate VARCHAR2(4000 BYTE) PATH 'IncorporationDate',
                    RegistrationDate VARCHAR2(4000 BYTE) PATH 'RegistrationDate',
                    Accounts_AccountRefDay VARCHAR2(4000 BYTE) PATH 'Accounts/AccountRefDay',
                    Accounts_AccountRefMonth VARCHAR2(4000 BYTE) PATH 'Accounts/AccountRefMonth',
                    Accounts_NextDueDate VARCHAR2(4000 BYTE) PATH 'Accounts/NextDueDate',
                    Accounts_LastMadeUpDate VARCHAR2(4000 BYTE) PATH 'Accounts/LastMadeUpDate',
                    Accounts_AccountCategory VARCHAR2(4000 BYTE) PATH 'Accounts/AccountCategory',
                    Returns_NextDueDate VARCHAR2(4000 BYTE) PATH 'Returns/NextDueDate',
                    Returns_LastMadeUpDate VARCHAR2(4000 BYTE) PATH 'Returns/LastMadeUpDate',
                    Mortgages_NumMortCharges VARCHAR2(4000 BYTE) PATH 'Mortgages/NumMortCharges',
                    Mortgages_NumMortOutstanding VARCHAR2(4000 BYTE) PATH 'Mortgages/NumMortOutstanding',
                    Mortgages_NumMortPartSatisfied VARCHAR2(4000 BYTE) PATH 'Mortgages/NumMortPartSatisfied',
                    Mortgages_NumMortSatisfied VARCHAR2(4000 BYTE) PATH 'Mortgages/NumMortSatisfied',
                    SICCodes XMLTYPE PATH 'SICCodes',
                    LimitedPartnerships_NumGenPart VARCHAR2(4000 BYTE) PATH 'LimitedPartnerships/NumGenPartners',
                    LimitedPartnerships_NumLimPart VARCHAR2(4000 BYTE) PATH 'LimitedPartnerships/NumLimPartners'
                ) A
                LEFT OUTER JOIN XMLTABLE
                (
                    XMLNAMESPACES(DEFAULT 'http://www.companieshouse.gov.uk/terms/xxx'),
                    'SICCodes'
                    PASSING A.SICCodes
                    COLUMNS
                    SICCodes_SicText#1 VARCHAR2(4000 BYTE) PATH 'SicText[1]',
                    SICCodes_SicText#2 VARCHAR2(4000 BYTE) PATH 'SicText[2]',
                    SICCodes_SicText#3 VARCHAR2(4000 BYTE) PATH 'SicText[3]',
                    SICCodes_SicText#4 VARCHAR2(4000 BYTE) PATH 'SicText[4]'
                ) B
                    ON 1 = 1
            )
            UNPIVOT
            INCLUDE NULLS
            (
                Value
                FOR FieldName IN
                (
                    CompanyName AS 'CompanyName',
                    CompanyNumber AS 'CompanyNumber',
                    RegAddress_CareofName AS 'RegAddress/CareofName',
                    RegAddress_PoBox AS 'RegAddress/PoBox',
                    RegAddress_AddressLine1 AS 'RegAddress/AddressLine1',
                    RegAddress_AddressLine2 AS 'RegAddress/AddressLine2',
                    RegAddress_PostTown AS 'RegAddress/PostTown',
                    RegAddress_County AS 'RegAddress/County',
                    RegAddress_Country AS 'RegAddress/Country',
                    RegAddress_Postcode AS 'RegAddress/Postcode',
                    CompanyCategory AS 'CompanyCategory',
                    CompanyStatus AS 'CompanyStatus',
                    CountryOfOrigin AS 'CountryOfOrigin',
                    DissolutionDate AS 'DissolutionDate',
                    IncorporationDate AS 'IncorporationDate',
                    RegistrationDate AS 'RegistrationDate',
                    Accounts_AccountRefDay AS 'Accounts/AccountRefDay',
                    Accounts_AccountRefMonth AS 'Accounts/AccountRefMonth',
                    Accounts_NextDueDate AS 'Accounts/NextDueDate',
                    Accounts_LastMadeUpDate AS 'Accounts/LastMadeUpDate',
                    Accounts_AccountCategory AS 'Accounts/AccountCategory',
                    Returns_NextDueDate AS 'Returns/NextDueDate',
                    Returns_LastMadeUpDate AS 'Returns/LastMadeUpDate',
                    Mortgages_NumMortCharges AS 'Mortgages/NumMortCharges',
                    Mortgages_NumMortOutstanding AS 'Mortgages/NumMortOutstanding',
                    Mortgages_NumMortPartSatisfied AS 'Mortgages/NumMortPartSatisfied',
                    Mortgages_NumMortSatisfied AS 'Mortgages/NumMortSatisfied',
                    SICCodes_SicText#1 AS 'SICCodes/SicText[1]',
                    SICCodes_SicText#2 AS 'SICCodes/SicText[2]',
                    SICCodes_SicText#3 AS 'SICCodes/SicText[3]',
                    SICCodes_SicText#4 AS 'SICCodes/SicText[4]',
                    LimitedPartnerships_NumGenPart AS 'LimitedPartnerships/NumGenPartners',
                    LimitedPartnerships_NumLimPart AS 'LimitedPartnerships/NumLimPartners'
                )
            )
        ) A
        INNER JOIN TABLE
        (
            SPLIT(gFieldNames)
        ) B
            ON UPPER(A.FieldName) = UPPER
                    (
                        TRIM
                        (
                            REPLACE
                            (
                                REPLACE
                                (
                                    B.Text,
                                    CHR(10),
                                    ''
                                ),
                                CHR(13),
                                ''
                            )
                        )
                    )
        ORDER BY B.Position
    ) LOOP
        
        --DBMS_OUTPUT.Put_Line(TO_CHAR(C.Position) || ': ' || C.Value);
        
        rSPLIT_TYPE.Position := C.Position;
        rSPLIT_TYPE.Text := C.Value;
        
        PIPE ROW(rSPLIT_TYPE);
        
    END LOOP;
    
    IF DBMS_LOB.GetLength(bData) > 0 THEN
        
        DBMS_LOB.Close(bData);
        
        DBMS_LOB.FreeTemporary(bData);
        
    END IF;
    
    RETURN;
    
EXCEPTION
WHEN OTHERS THEN
    
    vError := SUBSTRB
    (
        COALESCE(UTL_HTTP.Get_Detailed_SQLErrM, SQLErrM),
        1,
        255
    );
    
    DBMS_OUTPUT.Put_Line(vError);
    
    IF DBMS_LOB.GetLength(bData) > 0 THEN
        
        DBMS_LOB.Close(bData);
        
        DBMS_LOB.FreeTemporary(bData);
        
    END IF;
    
END;
/

/*
--Find non-ASCII characters to test
SELECT *
FROM COMPANYNAMECHARACTER
WHERE Name NOT IN
(
    SELECT UnicodeCharacter
    FROM ASCII
);
--No companies with «»

--test
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT *
FROM TABLE
(
    UKCHAPI
    (
        '02489169',
        'CompanyName,
        CompanyNumber,
        RegAddress/CareofName,
        RegAddress/PoBox,
        RegAddress/AddressLine1,
        RegAddress/AddressLine2,
        RegAddress/PostTown,
        RegAddress/County,
        RegAddress/Country,
        RegAddress/Postcode,
        CompanyCategory,
        CompanyStatus,
        CountryOfOrigin,
        DissolutionDate,
        IncorporationDate,
        RegistrationDate,
        Accounts/AccountRefDay,
        Accounts/AccountRefMonth,
        Accounts/NextDueDate,
        Accounts/LastMadeUpDate,
        Accounts/AccountCategory,
        Returns/NextDueDate,
        Returns/LastMadeUpDate,
        Mortgages/NumMortCharges,
        Mortgages/NumMortOutstanding,
        Mortgages/NumMortPartSatisfied,
        Mortgages/NumMortSatisfied,
        SICCodes/SicText[1],
        SICCodes/SicText[2],
        SICCodes/SicText[3],
        SICCodes/SicText[4],
        LimitedPartnerships/NumGenPartners,
        LimitedPartnerships/NumLimPartners'
    )
);

SELECT *
FROM TABLE
(
    UKCHAPI
    (
        '06523974',
        'CompanyName'
    )
); --Illegal character `

SELECT * FROM TABLE(UKCHAPI('06413833', 'CompanyName')); --Illegal character ~
SELECT * FROM TABLE(UKCHAPI('NI059553', 'companyname')); --Illegal character |
SELECT * FROM TABLE(UKCHAPI('ZZZ', 'CompanyName')); --Non-existent identifier
SELECT * FROM TABLE(UKCHAPI('FC028965', 'CompanyName'));
SELECT * FROM TABLE(UKCHAPI('08133579', 'Returns/LastMadeUpDate'));
SELECT * FROM TABLE(UKCHAPI('08152487', 'CompanyName')); --Pound signs
SELECT * FROM TABLE(UKCHAPI('NI073139', 'CompanyName')); --Accent
SELECT * FROM TABLE(UKCHAPI('04410318', 'CompanyName')); --Square brackets
SELECT * FROM TABLE(UKCHAPI('NF004216', 'CompanyName')); --Accent
SELECT * FROM TABLE(UKCHAPI('FC015324', 'CompanyName')); --double quotes
SELECT * FROM TABLE(UKCHAPI('08344348', 'CompanyName')); --Yen sign
SELECT * FROM TABLE(UKCHAPI('08464107', 'CompanyName')); --Euro sign
SELECT * FROM TABLE(UKCHAPI('06904076', 'CompanyName')); --´ sign, but using grave accent instead of inverted comma
SELECT * FROM TABLE(UKCHAPI('08497243', 'CompanyName')); --“” ’
SELECT * FROM TABLE(UKCHAPI('SC449411', 'CompanyName')); --‘ in the monthly feed, but replaced with ' in the API
SELECT * FROM TABLE(UKCHAPI('08851992', 'CompanyName, RegAddress/CareofName, RegAddress/PoBox, RegAddress/AddressLine1, RegAddress/AddressLine2, RegAddress/PostTown, RegAddress/County, RegAddress/Country, RegAddress/Postcode,')); --postcode has been corrected
SELECT * FROM TABLE(UKCHAPI('FC029274', 'SICCodes/SicText[1]')); --SICCodes_SICText#1 is 'None Supplied'

SELECT *
FROM
(
    SELECT *
    FROM TABLE
    (
        UKCHAPI
        (
            '02489169',
            'CompanyName,
            CompanyNumber,
            RegAddress/CareofName,
            RegAddress/PoBox,
            RegAddress/AddressLine1,
            RegAddress/AddressLine2,
            RegAddress/PostTown,
            RegAddress/County,
            RegAddress/Country,
            RegAddress/Postcode,
            CompanyCategory,
            CompanyStatus,
            CountryOfOrigin,
            DissolutionDate,
            IncorporationDate,
            RegistrationDate,
            Accounts/AccountRefDay,
            Accounts/AccountRefMonth,
            Accounts/NextDueDate,
            Accounts/LastMadeUpDate,
            Accounts/AccountCategory,
            Returns/NextDueDate,
            Returns/LastMadeUpDate,
            Mortgages/NumMortCharges,
            Mortgages/NumMortOutstanding,
            Mortgages/NumMortPartSatisfied,
            Mortgages/NumMortSatisfied,
            SICCodes/SicText[1],
            SICCodes/SicText[2],
            SICCodes/SicText[3],
            SICCodes/SicText[4],
            LimitedPartnerships/NumGenPartners,
            LimitedPartnerships/NumLimPartners'
        )
    )
)
PIVOT
(
    MAX(Text)
    FOR Position IN
    (
        1 AS CompanyName,
        2 AS CompanyNumber,
        3 AS RegAddress_CareofName,
        4 AS RegAddress_PoBox,
        5 AS RegAddress_AddressLine1,
        6 AS RegAddress_AddressLine2,
        7 AS RegAddress_PostTown,
        8 AS RegAddress_County,
        9 AS RegAddress_Country,
        10 AS RegAddress_Postcode,
        11 AS CompanyCategory,
        12 AS CompanyStatus,
        13 AS CountryOfOrigin,
        14 AS DissolutionDate,
        15 AS IncorporationDate,
        16 AS RegistrationDate,
        17 AS Accounts_AccountRefDay,
        18 AS Accounts_AccountRefMonth,
        19 AS Accounts_NextDueDate,
        20 AS Accounts_LastMadeUpDate,
        21 AS Accounts_AccountCategory,
        22 AS Returns_NextDueDate,
        23 AS Returns_LastMadeUpDate,
        24 AS Mortgages_NumMortCharges,
        25 AS Mortgages_NumMortOutstanding,
        26 AS Mortgages_NumMortPartSatisfied,
        27 AS Mortgages_NumMortSatisfied,
        28 AS SICCodes_SicText#1,
        29 AS SICCodes_SicText#2,
        30 AS SICCodes_SicText#3,
        31 AS SICCodes_SicText#4,
        32 AS LimitedPartnerships_NumGenPart,
        33 AS LimitedPartnerships_NumLimPart
    )
);
*/