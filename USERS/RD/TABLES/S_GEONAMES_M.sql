--DROP TABLE S_GEONAMES_M PURGE;
--Take into account possible negative sign for latitude and longitude
--Filler being empty causes LRTRIM to fail the whole export (thinks the field isn't there)
CREATE
TABLE S_GEONAMES_M
(
    GEONAMESID INTEGER,
    NAME VARCHAR2(200 CHAR),
    ASCIINAME VARCHAR2(200 BYTE),
    LATITUDE NUMBER(7,5),
    LONGITUDE NUMBER(8,5),
    FEATURECLASS CHAR(1 BYTE),
    FEATURECODE VARCHAR2(5 BYTE),
    COUNTRYCODE CHAR(2 BYTE),
    CC2 VARCHAR2(1000 BYTE),
    ADMIN1CODE VARCHAR2(20 BYTE),
    ADMIN2CODE VARCHAR2(80 BYTE),
    ADMIN3CODE VARCHAR2(20 BYTE),
    ADMIN4CODE VARCHAR2(20 BYTE),
    POPULATION INTEGER,
    ELEVATION INTEGER,
    DEM INTEGER,
    TIMEZONE VARCHAR2(100 BYTE),
    MODIFICATIONDATE DATE
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
            GEONAMESID INTEGER EXTERNAL(255),
            NAME CHAR(800),
            ASCIINAME CHAR(200),
            FILLER CHAR(32767),
            LATITUDE DECIMAL EXTERNAL(9),
            LONGITUDE DECIMAL EXTERNAL(10),
            FEATURECLASS CHAR(1),
            FEATURECODE CHAR(5),
            COUNTRYCODE CHAR(2),
            CC2 CHAR(1000),
            ADMIN1CODE CHAR(20),
            ADMIN2CODE CHAR(80),
            ADMIN3CODE CHAR(20),
            ADMIN4CODE CHAR(20),
            POPULATION INTEGER EXTERNAL(255),
            ELEVATION INTEGER EXTERNAL(255),
            DEM INTEGER EXTERNAL(255),
            "TIMEZONE" CHAR(100),
            MODIFICATIONDATE CHAR DATE_FORMAT DATE MASK "YYYY-MM-DD"
        )
    )
    LOCATION ('S_GEONAMES_M.tsv')
)
PARALLEL
NOMONITORING
--REJECT LIMIT 1
;