--DROP TABLE S_GEONAMESADMIN1CODE PURGE;
CREATE
TABLE S_GEONAMESADMIN1CODE 
(
    ID VARCHAR2(20 BYTE),
    NAMEOFFICIAL VARCHAR2(200 CHAR),
    NAME VARCHAR2(200 BYTE),
    GEONAMESID INTEGER
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
        FIELDS TERMINATED BY 0X'09'
        REJECT ROWS WITH ALL NULL FIELDS
        (
            ID CHAR(20),
            NAMEOFFICIAL CHAR(800),
            NAME CHAR(200),
            GEONAMESID INTEGER EXTERNAL(255)
        )
    )
    LOCATION ('S_GEONAMESADMIN1CODE.tsv')
)
PARALLEL
NOMONITORING
--REJECT LIMIT 1
;