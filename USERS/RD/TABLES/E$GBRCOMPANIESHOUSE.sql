--DROP TABLE S_GBRCOMPANIESHOUSE PURGE;
CREATE
TABLE S_GBRCOMPANIESHOUSE
(
    CompanyName VARCHAR2(4000 BYTE),
    CompanyNumber VARCHAR2(8 BYTE),
    RegAddress_CareOf VARCHAR2(4000 BYTE),
    RegAddress_POBox VARCHAR2(4000 BYTE),
    RegAddress_AddressLine1 VARCHAR2(4000 BYTE),
    RegAddress_AddressLine2 VARCHAR2(4000 BYTE),
    RegAddress_PostTown VARCHAR2(4000 BYTE),
    RegAddress_County VARCHAR2(4000 BYTE),
    RegAddress_Country VARCHAR2(4000 BYTE),
    RegAddress_PostCode VARCHAR2(4000 BYTE),
    CompanyCategory VARCHAR2(4000 BYTE),
    CompanyStatus VARCHAR2(4000 BYTE),
    CountryOfOrigin VARCHAR2(4000 BYTE),
    DissolutionDate DATE,
    IncorporationDate DATE,
    Accounts_AccountRefDay NUMBER(2),
    Accounts_AccountRefMonth NUMBER(2),
    Accounts_NextDueDate DATE,
    Accounts_LastMadeUpDate DATE,
    Accounts_AccountCategory VARCHAR2(4000 BYTE),
    Returns_NextDueDate DATE,
    Returns_LastMadeUpDate DATE,
    Mortgages_NumMortCharges NUMBER,
    Mortgages_NumMortOutstanding NUMBER,
    Mortgages_NumMortPartSatisfied NUMBER,
    Mortgages_NumMortSatisfied NUMBER,
    SICCode_SicText_1 VARCHAR2(4000 BYTE),
    SICCode_SicText_2 VARCHAR2(4000 BYTE),
    SICCode_SicText_3 VARCHAR2(4000 BYTE),
    SICCode_SicText_4 VARCHAR2(4000 BYTE),
    LtdPartnerships_NumGenPartners NUMBER,
    LtdPartnerships_NumLimPartners NUMBER,
    URI VARCHAR2(4000 BYTE),
    PreviousName_1_CONDATE DATE,
    PreviousName_1_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_2_CONDATE DATE,
    PreviousName_2_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_3_CONDATE DATE,
    PreviousName_3_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_4_CONDATE DATE,
    PreviousName_4_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_5_CONDATE DATE,
    PreviousName_5_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_6_CONDATE DATE,
    PreviousName_6_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_7_CONDATE DATE,
    PreviousName_7_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_8_CONDATE DATE,
    PreviousName_8_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_9_CONDATE DATE,
    PreviousName_9_CompanyName VARCHAR2(4000 BYTE),
    PreviousName_10_CONDATE DATE,
    PreviousName_10_CompanyName VARCHAR2(4000 BYTE),
    ConfStmtNextDueDate DATE,
    ConfStmtLastMadeUpDate DATE
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY RD
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY 0X'0A'
        SKIP 1
        CHARACTERSET UTF8
        STRING SIZES ARE IN BYTES
        NOBADFILE NOLOGFILE NODISCARDFILE
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'unzip.sh'
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            CompanyName CHAR(4000),
            CompanyNumber CHAR(8),
            RegAddress_CareOf CHAR(4000),
            RegAddress_POBox CHAR(4000),
            RegAddress_AddressLine1 CHAR(4000),
            RegAddress_AddressLine2 CHAR(4000),
            RegAddress_PostTown CHAR(4000),
            RegAddress_County CHAR(4000),
            RegAddress_Country CHAR(4000),
            RegAddress_PostCode CHAR(4000),
            CompanyCategory CHAR(4000),
            CompanyStatus CHAR(4000),
            CountryOfOrigin CHAR(4000),
            DissolutionDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            IncorporationDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            Accounts_AccountRefDay CHAR(2),
            Accounts_AccountRefMonth CHAR(2),
            Accounts_NextDueDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            Accounts_LastMadeUpDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            Accounts_AccountCategory CHAR(4000),
            Returns_NextDueDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            Returns_LastMadeUpDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            Mortgages_NumMortCharges CHAR(4000),
            Mortgages_NumMortOutstanding CHAR(4000),
            Mortgages_NumMortPartSatisfied CHAR(4000),
            Mortgages_NumMortSatisfied CHAR(4000),
            SICCode_SicText_1 CHAR(4000),
            SICCode_SicText_2 CHAR(4000),
            SICCode_SicText_3 CHAR(4000),
            SICCode_SicText_4 CHAR(4000),
            LtdPartnerships_NumGenPartners CHAR(4000),
            LtdPartnerships_NumLimPartners CHAR(4000),
            URI CHAR(4000),
            PreviousName_1_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_1_CompanyName CHAR(4000),
            PreviousName_2_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_2_CompanyName CHAR(4000),
            PreviousName_3_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_3_CompanyName CHAR(4000),
            PreviousName_4_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_4_CompanyName CHAR(4000),
            PreviousName_5_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_5_CompanyName CHAR(4000),
            PreviousName_6_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_6_CompanyName CHAR(4000),
            PreviousName_7_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_7_CompanyName CHAR(4000),
            PreviousName_8_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_8_CompanyName CHAR(4000),
            PreviousName_9_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_9_CompanyName CHAR(4000),
            PreviousName_10_CONDATE CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            PreviousName_10_CompanyName CHAR(4000),
            ConfStmtNextDueDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY",
            ConfStmtLastMadeUpDate CHAR DATE_FORMAT DATE MASK "DD/MM/YYYY"
        )
    )
    LOCATION('BasicCompanyDataAsOneFile-*.zip')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 1
;

/*
--test
SELECT *
FROM S_GBRCOMPANIESHOUSE;
*/