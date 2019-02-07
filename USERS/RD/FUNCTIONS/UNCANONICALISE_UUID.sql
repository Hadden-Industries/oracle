CREATE OR REPLACE
FUNCTION UNCANONICALISE_UUID(gUUID VARCHAR2)
RETURN RAW
DETERMINISTIC PARALLEL_ENABLE
AS

    PRAGMA UDF;

BEGIN

    RETURN HEXTORAW
    (
        CASE
        WHEN IS_UUID(gUUID) = 1 THEN REPLACE
        (
            RTRIM
            (
                LTRIM(gUUID, '{'),
                '}'
            ),
            '-'
        )
        ELSE NULL
        END
    );
    
END ;
/

/*
--test
SELECT UNCANONICALISE_UUID('D1937A2D-BFD3-44E9-928F-29AC5E1C481B')
FROM DUAL;

SELECT UNCANONICALISE_UUID('109e8a33-5d36-4880-a50f-b5ce68e48f90')
FROM DUAL;

SELECT UNCANONICALISE_UUID('D1937A2DBFD344E9928F29AC5E1C481B')
FROM DUAL;

SELECT UNCANONICALISE_UUID(UUID_VER4)
FROM DUAL;
*/