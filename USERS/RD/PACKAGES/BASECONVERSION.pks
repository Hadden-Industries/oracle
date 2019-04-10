SET SERVEROUTPUT ON;
 
CREATE OR REPLACE
PACKAGE BASECONVERSION
AS
   FUNCTION BIN2DEC (binval IN CHAR) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
   FUNCTION DEC2BIN (N IN NUMBER) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
   FUNCTION OCT2DEC (octval IN CHAR) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
   FUNCTION DEC2OCT (N IN NUMBER) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
   FUNCTION HEX2DEC (hexval IN CHAR) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
   FUNCTION DEC2HEX (N IN NUMBER) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
END BASECONVERSION;
/

GRANT EXECUTE ON BASECONVERSION TO PUBLIC;