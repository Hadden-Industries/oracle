--DROP TABLE S_TIMEZONE PURGE;
CREATE
TABLE S_TIMEZONE
(
    COUNTRY_ALPHA2 CHAR(2 BYTE),
    NAME VARCHAR2(100 CHAR),
    OFFSETGMT NUMBER,
    OFFSETDST NUMBER,
    OFFSETRAW NUMBER
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
        FIELDS TERMINATED BY 0X'09'
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            COUNTRY_ALPHA2 CHAR(2),
            "NAME" CHAR(400),
            OFFSETGMT DECIMAL EXTERNAL(6),
            OFFSETDST DECIMAL EXTERNAL(6),
            OFFSETRAW DECIMAL EXTERNAL(6)
        )
    )
    LOCATION ('S_TIMEZONE.txt')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 1
;

/*
--test
SELECT *
FROM S_TIMEZONE
WHERE Name = 'Pacific/Chatham'
;
*/