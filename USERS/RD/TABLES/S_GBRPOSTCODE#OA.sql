--DROP TABLE S_GBRPOSTCODE#OA PURGE;
CREATE
TABLE S_GBRPOSTCODE#OA
(
    PCD7 VARCHAR2(7 BYTE),
    PCD8 VARCHAR2(8 BYTE),
    OA11CD CHAR(9 BYTE),
    LSOA11CD CHAR(9 BYTE),
    LSOA11NM VARCHAR2(254 BYTE),
    MSOA11CD CHAR(9 BYTE),
    MSOA11NM VARCHAR2(254 BYTE),
    LAD11CD CHAR(9 BYTE),
    LAD11NM VARCHAR2(254 BYTE),
    LAD11NMW VARCHAR2(254 BYTE),
    PCDOASPLT NUMBER(1,0)
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY RD
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY NEWLINE
        SKIP 1
        CHARACTERSET WE8ISO8859P1
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'unzip_S_GBRPOSTCODE#OA.sh'
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            PCD7 CHAR(7),
            PCD8 CHAR(8),
            OA11CD CHAR(9),
            LSOA11CD CHAR(9),
            LSOA11NM CHAR(254),
            MSOA11CD CHAR(9),
            MSOA11NM CHAR(254),
            LAD11CD CHAR(9),
            LAD11NM CHAR(254),
            LAD11NMW CHAR(254),
            PCDOASPLT CHAR(1)
        )
    )
    LOCATION('Postcodes_(Enumeration)_(2011)_to_OA.zip')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 100
;

/*
--test
SELECT *
FROM S_GBRPOSTCODE#OA;

Below is not currently supported:
SQL Error: ORA-30657: operation not supported on external organized table
30657.0000 -  "operation not supported on external organized table"
*Cause:    User attempted on operation on an external table which is
           not supported.
*Action:   Don't do that!
*/
/*
COMMENT ON COLUMN S_GBRPOSTCODE#OA.PCD7 IS '2011 7 character postcode';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.PCD8 IS '2011 8 character postcode';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.OA11CD IS '2011 output area code';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.LSOA11CD IS '2011 lower layer super output area code'; 
COMMENT ON COLUMN S_GBRPOSTCODE#OA.LSOA11NM IS '2011 lower layer super output area name';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.MSOA11CD IS '2011 middle layer super output area code';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.MSOA11NM IS '2011 middle layer super output area name';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.LAD11CD IS '2011 local authority district code';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.LAD11NM IS '2011 local authority district name';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.LAD11NMW IS '2011 local authority district Welsh name equivalent';
COMMENT ON COLUMN S_GBRPOSTCODE#OA.PCDOASPLT IS '2011 Indicator of where postcodes are split across more than one OA';
*/