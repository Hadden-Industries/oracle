--Replaced SKIP 1 with REJECT LIMIT 1 to prevent internal error
--DROP TABLE S_GBRONSPD PURGE;
CREATE
TABLE S_GBRONSPD
(
    pcd VARCHAR2(7 BYTE),
    pcd2 VARCHAR2(8 BYTE),
    pcds VARCHAR2(8 BYTE),
    dointr DATE,
    doterm DATE,
    oscty VARCHAR2(9 BYTE),
    ced VARCHAR2(9 BYTE),
    oslaua VARCHAR2(9 BYTE),
    osward VARCHAR2(9 BYTE),
    parish VARCHAR2(9 BYTE),
    usertype NUMBER(1,0),
    oseast1m INTEGER,
    osnrth1m INTEGER,
    osgrdind NUMBER(1,0),
    oshlthau VARCHAR2(9 BYTE),
    nhser VARCHAR2(9 BYTE),
    ctry VARCHAR2(9 BYTE),
    rgn VARCHAR2(9 BYTE),
    streg VARCHAR2(1 BYTE),
    pcon VARCHAR2(9 BYTE),
    eer VARCHAR2(9 BYTE),
    teclec VARCHAR2(9 BYTE),
    ttwa VARCHAR2(9 BYTE),
    pct VARCHAR2(9 BYTE),
    nuts VARCHAR2(10 BYTE),
    statsward VARCHAR2(6 BYTE),
    oa01 VARCHAR2(10 BYTE),
    casward VARCHAR2(6 BYTE),
    park VARCHAR2(9 BYTE),
    lsoa01 VARCHAR2(9 BYTE),
    msoa01 VARCHAR2(9 BYTE),
    ur01ind CHAR(1 BYTE),
    oac01 VARCHAR2(3 BYTE),
    oa11 VARCHAR2(9 BYTE),
    lsoa11 VARCHAR2(9 BYTE),
    msoa11 VARCHAR2(9 BYTE),
    wz11 VARCHAR2(9 BYTE),
    ccg VARCHAR2(9 BYTE),
    bua11 VARCHAR2(9 BYTE),
    buasd11 VARCHAR2(9 BYTE),
    ru11ind VARCHAR2(2 BYTE),
    oac11 VARCHAR2(9 BYTE),
    lat NUMBER(10,8),
    long_ NUMBER(10,7),
    lep1 VARCHAR2(9 BYTE),
    lep2 VARCHAR2(9 BYTE),
    pfa VARCHAR2(9 BYTE),
    imd INTEGER,
    calncv VARCHAR2(9 BYTE),
    stp VARCHAR2(9 BYTE)
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY RD
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY 0X'0A'
        CHARACTERSET WE8ISO8859P1
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'unzip_S_GBRONSPD.sh'
        FIELDS TERMINATED BY "," OPTIONALLY ENCLOSED BY '"'
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            pcd CHAR(7),
            pcd2 CHAR(8),
            pcds CHAR(8),
            dointr CHAR DATE_FORMAT DATE MASK "YYYYMM",
            doterm CHAR DATE_FORMAT DATE MASK "YYYYMM",
            oscty CHAR(9),
            ced CHAR(9),
            oslaua CHAR(9),
            osward CHAR(9),
            parish CHAR(9),
            usertype INTEGER EXTERNAL(1),
            oseast1m INTEGER EXTERNAL(255),
            osnrth1m INTEGER EXTERNAL(255),
            osgrdind INTEGER EXTERNAL(1),
            oshlthau CHAR(9),
            nhser CHAR(9),
            ctry CHAR(9),
            rgn CHAR(9),
            streg CHAR(1),
            pcon CHAR(9),
            eer CHAR(9),
            teclec CHAR(9),
            ttwa CHAR(9),
            pct CHAR(9),
            nuts CHAR(10),
            statsward CHAR(6),
            oa01 CHAR(10),
            casward CHAR(6),
            park CHAR(9),
            lsoa01 CHAR(9),
            msoa01 CHAR(9),
            ur01ind CHAR(1),
            oac01 CHAR(3),
            oa11 CHAR(9),
            lsoa11 CHAR(9),
            msoa11 CHAR(9),
            wz11 CHAR(9),
            ccg CHAR(9),
            bua11 CHAR(9),
            buasd11 CHAR(9),
            ru11ind CHAR(2),
            oac11 CHAR(9),
            lat DECIMAL EXTERNAL(10),
            long_ DECIMAL EXTERNAL(10),
            lep1 CHAR(9),
            lep2 CHAR(9),
            pfa CHAR(9),
            imd INTEGER EXTERNAL(255),
            calncv CHAR(9),
            stp CHAR(9) LRTRIM
        )
    )
    LOCATION('ONSPD_*.zip')
)
NOPARALLEL
NOMONITORING
REJECT LIMIT 1
;

/*
--test
SELECT *
FROM S_GBRONSPD;
*/