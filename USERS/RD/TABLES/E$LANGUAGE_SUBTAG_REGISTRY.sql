--DROP TABLE E$LANGUAGE_SUBTAG_REGISTRY PURGE;
CREATE
TABLE E$LANGUAGE_SUBTAG_REGISTRY
(
    VAL1 VARCHAR2(100 BYTE),
    VAL2 VARCHAR2(100 BYTE),
    VAL3 VARCHAR2(100 BYTE),
    VAL4 VARCHAR2(100 BYTE),
    VAL5 VARCHAR2(100 BYTE),
    VAL6 VARCHAR2(100 BYTE),
    VAL7 VARCHAR2(100 BYTE),
    VAL8 VARCHAR2(100 BYTE),
    VAL9 VARCHAR2(100 BYTE),
    VAL10 VARCHAR2(100 BYTE),
    VAL11 VARCHAR2(100 BYTE),
    VAL12 VARCHAR2(100 BYTE),
    VAL13 VARCHAR2(100 BYTE),
    VAL14 VARCHAR2(100 BYTE),
    VAL15 VARCHAR2(100 BYTE),
    VAL16 VARCHAR2(100 BYTE),
    VAL17 VARCHAR2(100 BYTE),
    VAL18 VARCHAR2(100 BYTE),
    VAL19 VARCHAR2(100 BYTE),
    VAL20 VARCHAR2(100 BYTE)
)
ORGANIZATION EXTERNAL 
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY RD
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY 0X'25250A'
        SKIP 1
        CHARACTERSET UTF8
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        FIELDS TERMINATED BY 0X'0A'
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            VAL1 CHAR(100),
            VAL2 CHAR(100),
            VAL3 CHAR(100),
            VAL4 CHAR(100),
            VAL5 CHAR(100),
            VAL6 CHAR(100),
            VAL7 CHAR(100),
            VAL8 CHAR(100),
            VAL9 CHAR(100),
            VAL10 CHAR(100),
            VAL11 CHAR(100),
            VAL12 CHAR(100),
            VAL13 CHAR(100),
            VAL14 CHAR(100),
            VAL15 CHAR(100),
            VAL16 CHAR(100),
            VAL17 CHAR(100),
            VAL18 CHAR(100),
            VAL19 CHAR(100),
            VAL20 CHAR(100)
        )
    )
    LOCATION('language-subtag-registry.txt')
)
NOPARALLEL
NOMONITORING
;

/* test */

SELECT *
FROM
(
    SELECT VAL1,
    VAL2,
    VAL3,
    VAL4,
    VAL5,
    VAL6,
    VAL7,
    VAL8,
    VAL9,
    VAL10,
    VAL11,
    VAL12,
    VAL13,
    VAL14,
    VAL15,
    VAL16,
    VAL17,
    VAL18,
    VAL19,
    VAL20
    FROM E$LANGUAGE_SUBTAG_REGISTRY
)
UNPIVOT
(
    VAL
    FOR FIELDNUMBER IN (VAL1,
    VAL2,
    VAL3,
    VAL4,
    VAL5,
    VAL6,
    VAL7,
    VAL8,
    VAL9,
    VAL10,
    VAL11,
    VAL12,
    VAL13,
    VAL14,
    VAL15,
    VAL16,
    VAL17,
    VAL18,
    VAL19,
    VAL20)
)
WHERE VAL LIKE '%Comments%';

SELECT *
FROM E$LANGUAGE_SUBTAG_REGISTRY
WHERE Val20 LIKE '  %'
;