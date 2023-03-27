--DROP TABLE S_ISO15924 PURGE;
--SKIP doesn't seem to work with PREPROCESSOR, hence using REJECT LIMIT
CREATE
TABLE S_ISO15924
(
    ID CHAR(4 BYTE),
    NUMERICCODE CHAR(3 BYTE),
    NAME VARCHAR2(100 BYTE),
    NAMEFRENCH VARCHAR2(100 CHAR),
    PROPERTYVALUEALIAS VARCHAR2(100 CHAR),
    AGE NUMBER,
    DATEMODIFIED DATE
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY RD
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY 0X'0A'
        CHARACTERSET UTF8
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        PREPROCESSOR EXE:'unzip_S_ISO15924.sh'
        FIELDS TERMINATED BY ';'
        REJECT ROWS WITH ALL NULL FIELDS
        (
            ID CHAR (4),
            NUMERICCODE CHAR(3),
            NAME CHAR(100),
            NAMEFRENCH CHAR(400),
            PROPERTYVALUEALIAS CHAR(400),
            AGE CHAR,
            DATEMODIFIED CHAR DATE_FORMAT DATE MASK "YYYY-MM-DD"
        )
    )
    LOCATION('iso15924.txt.zip')
)
NOPARALLEL
NOMONITORING
REJECT LIMIT 7
;

/*
--test
SELECT *
FROM S_ISO15924;
*/