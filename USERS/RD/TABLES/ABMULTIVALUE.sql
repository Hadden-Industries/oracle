--DROP TABLE ABMULTIVALUE PURGE;
CREATE
TABLE ABMULTIVALUE
(
    UID_ INTEGER,
    RECORD_ID INTEGER,
    PROPERTY INTEGER,
    IDENTIFIER_ INTEGER,
    LABEL INTEGER,
    VALUE VARCHAR2(4000 BYTE),
    GUID VARCHAR2(4000 BYTE)
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY SQLITE
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY NEWLINE
        SKIP 2
        CHARACTERSET UTF8
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'ABMULTIVALUE.sh'
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            UID_ INTEGER EXTERNAL(255),
            RECORD_ID INTEGER EXTERNAL(255),
            PROPERTY INTEGER EXTERNAL(255),
            IDENTIFIER_ INTEGER EXTERNAL(255),
            LABEL INTEGER EXTERNAL(255),
            VALUE CHAR(4000),
            GUID CHAR(4000)
        )
    )
    LOCATION('31bb7ba8914766d4ba40d6dfb6113c8b614be442')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 100
;

/*
--test
SELECT *
FROM ABMULTIVALUE;
*/