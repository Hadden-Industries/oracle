--RAW maps to byte[] as per http://docs.oracle.com/cd/B19306_01/java.102/b14187/chsix.htm#BABJIJEB

CREATE OR REPLACE
FUNCTION UUID_VER3(Name IN RAW)
RETURN VARCHAR2
PARALLEL_ENABLE
DETERMINISTIC
AS LANGUAGE JAVA
NAME 'java.util.UUID.nameUUIDFromBytes(byte[]) return java.lang.String';
/

/*
--test
SELECT UUID_VER3(UTL_RAW.CAST_TO_RAW('http://geonames.org'))
FROM DUAL
;
--c91bf446-1338-3485-8de0-3804e13910a4
*/