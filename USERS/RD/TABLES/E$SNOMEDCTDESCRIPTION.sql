--DROP TABLE S_SNOMEDCTDESCRIPTION PURGE;
CREATE
TABLE S_SNOMEDCTDESCRIPTION
(
    ID INTEGER,
    effectiveTime DATE,
    active NUMBER(1,0),
    moduleId INTEGER,
    conceptId INTEGER,
    languageCode VARCHAR2(3 BYTE),
    typeId INTEGER,
    term VARCHAR2(255 BYTE),
    caseSignificanceId INTEGER
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
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'unzip_S_SNOMEDCTDESCRIPTION.sh'
        FIELDS TERMINATED BY 0X'09'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            ID CHAR,
            effectiveTime CHAR DATE_FORMAT DATE MASK "YYYYMMDD",
            active CHAR,
            moduleId CHAR,
            conceptId CHAR,
            languageCode CHAR(3),
            typeId CHAR,
            term CHAR(255),
            caseSignificanceId CHAR
        )
    )
    LOCATION('SnomedCT_*.zip')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 1
;

/*
--test
SELECT *
FROM S_SNOMEDCTDESCRIPTION-- WHERE ConceptID = 900000000000003001
--WHERE Term LIKE 'Synonym%'
WHERE ConceptID = 278149003
--Fully specified name
AND TypeID = 900000000000003001
;
*/