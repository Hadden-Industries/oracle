--DROP TABLE ABTHUMBNAILIMAGE PURGE;
--hex gets an extra CHR(10) at end, hence need LRTRIM
CREATE
TABLE ABTHUMBNAILIMAGE
(
    RECORD_ID INTEGER,
    FORMAT INTEGER,
    DERIVED_FROM_FORMAT INTEGER,
    DATA_ CLOB
)
ORGANIZATION EXTERNAL
(
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY SQLITE
    ACCESS PARAMETERS
    (
        RECORDS DELIMITED BY NEWLINE
        READSIZE 16777216
        SKIP 2
        CHARACTERSET UTF8
        NOBADFILE NOLOGFILE NODISCARDFILE
        STRING SIZES ARE IN BYTES
        DISABLE_DIRECTORY_LINK_CHECK
        PREPROCESSOR EXE:'ABTHUMBNAILIMAGE.sh'
        FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
        LRTRIM
        MISSING FIELD VALUES ARE NULL
        REJECT ROWS WITH ALL NULL FIELDS
        (
            RECORD_ID INTEGER EXTERNAL(255),
            "FORMAT" INTEGER EXTERNAL(255),
            DERIVED_FROM_FORMAT INTEGER EXTERNAL(255),
            DATA_ CHAR(16777216)
        )
    )
    LOCATION('cd6702cea29fe89cf280a76794405adb17f9a0ee')
)
NOPARALLEL
NOMONITORING
--REJECT LIMIT 100
;

/*
--test
SELECT Record_ID,
Format,
Derived_From_Format,
--Data_,
CLOB_IN_HEX_TO_BLOB(Data_) AS BLOB$Data_
FROM ABTHUMBNAILIMAGE
WHERE Derived_From_Format != 2
;
*/