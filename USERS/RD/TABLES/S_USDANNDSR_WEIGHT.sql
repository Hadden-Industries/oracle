--DROP TABLE S_USDANNDSR_WEIGHT PURGE;
/*
NUM_DATA_PTS defined as N 3, but has N 4 in the data
*/
CREATE
TABLE S_USDANNDSR_WEIGHT
(
    NDB_NO VARCHAR2(5 BYTE),
    SEQ VARCHAR2(2 BYTE),
    AMOUNT NUMBER(8, 3),
    MSRE_DESC VARCHAR2(84 BYTE),
    GM_WGT NUMBER(8, 1),
    NUM_DATA_PTS NUMBER(4),
    STD_DEV NUMBER(10, 3)
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
            SEQ CHAR(2),
            AMOUNT DECIMAL EXTERNAL(8),
            MSRE_DESC CHAR(84),
            GM_WGT DECIMAL EXTERNAL(8),
            NUM_DATA_PTS INTEGER EXTERNAL(4),
            STD_DEV DECIMAL EXTERNAL(10)
        )
    )
    LOCATION('S_USDANNDSR_WEIGHT.txt')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 100
;

/*
--test
SELECT NDB_No,
Seq,
Amount,
Msre_Desc,
Gm_Wgt,
Num_Data_Pts,
Std_Dev
FROM S_USDANNDSR_WEIGHT;
*/