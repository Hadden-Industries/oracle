--DROP TABLE E$ISO_639_3 PURGE;
CREATE
TABLE E$ISO_639_3
(
    ID CHAR(3 BYTE),
    PART2B CHAR(3 BYTE),
    PART2T CHAR(3 BYTE),
    PART1 CHAR(2 BYTE),
    SCOPE CHAR(1 BYTE),
    LANGUAGE_TYPE CHAR(1 BYTE),
    REF_NAME VARCHAR2(150 BYTE),
    "COMMENT" VARCHAR2(150 BYTE)
)
ORGANIZATION EXTERNAL 
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "RD"
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
            ID CHAR(3),
            PART2B CHAR(3),
            PART2T CHAR(3),
            PART1 CHAR(2),
            SCOPE CHAR(1),
            LANGUAGE_TYPE CHAR(1),
            REF_NAME CHAR(150),
            "COMMENT" CHAR(150) LRTRIM
        )
    )
    LOCATION('iso-639-3.tab')
)
NOPARALLEL
NOMONITORING
;