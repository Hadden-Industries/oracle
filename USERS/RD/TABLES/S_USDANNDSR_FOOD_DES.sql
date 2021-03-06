--DROP TABLE S_USDANNDSR_FOOD_DES PURGE;
/*
For some reason, CHO_FACTOR acquires an extra CHR(10) at the end
and this prevents a direct number conversion.
Use the LRTRIM spec to get rid of it.
*/
CREATE
TABLE S_USDANNDSR_FOOD_DES
(
    NDB_NO VARCHAR2(5 BYTE),
    FDGRP_CD VARCHAR2(4 BYTE),
    LONG_DESC VARCHAR2(200 BYTE),
    SHRT_DESC VARCHAR2(60 BYTE),
    COMNAME VARCHAR2(100 BYTE),
    MANUFACNAME VARCHAR2(65 BYTE),
    SURVEY CHAR(1 BYTE),
    REF_DESC VARCHAR2(135 BYTE),
    REFUSE NUMBER(2),
    SCINAME VARCHAR2(65 BYTE),
    N_FACTOR NUMBER(6, 2),
    PRO_FACTOR NUMBER(6, 2),
    FAT_FACTOR NUMBER(6, 2),
    CHO_FACTOR NUMBER(6, 2)
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
        FIELDS TERMINATED BY '^' OPTIONALLY ENCLOSED BY '~' LRTRIM
        (
            NDB_NO CHAR(5),
            FDGRP_CD CHAR(4),
            LONG_DESC CHAR(200),
            SHRT_DESC CHAR(60),
            COMNAME CHAR(100),
            MANUFACNAME CHAR(65),
            SURVEY CHAR(1),
            REF_DESC CHAR(135),
            REFUSE INTEGER EXTERNAL(2),
            SCINAME CHAR(65),
            N_FACTOR DECIMAL EXTERNAL(6),
            PRO_FACTOR DECIMAL EXTERNAL(6),
            FAT_FACTOR DECIMAL EXTERNAL(6),
            CHO_FACTOR DECIMAL EXTERNAL(6)
        )
    )
    LOCATION('S_USDANNDSR_FOOD_DES.txt')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 100
;

/*
--test
SELECT NDB_No,
FdGrp_Cd,
Long_Desc,
Shrt_Desc,
ComName,
ManufacName,
Survey,
Ref_Desc,
Refuse,
SciName,
N_Factor,
Pro_Factor,
Fat_Factor,
CHO_Factor
FROM S_USDANNDSR_FOOD_DES;
*/
