--DROP TABLE ABMULTIVALUELABEL PURGE;
CREATE
TABLE ABMULTIVALUELABEL
(
    ROWID_ INTEGER,
    VALUE VARCHAR2(4000 BYTE)
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
        PREPROCESSOR EXE:'ABMULTIVALUELABEL.sh'
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            ROWID_ INTEGER EXTERNAL(255),
            VALUE CHAR(4000)
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
FROM ABMULTIVALUELABEL;
*/