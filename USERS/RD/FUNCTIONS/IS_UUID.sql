CREATE OR REPLACE
FUNCTION IS_UUID(gText IN VARCHAR2)
RETURN NUMBER
DETERMINISTIC PARALLEL_ENABLE
AS
  
  PRAGMA UDF;
  
BEGIN
  
  RETURN CASE
      WHEN REGEXP_LIKE
      (
          REPLACE
          (
              RTRIM
              (
                  LTRIM(gText, '{'),
                  '}'
              ),
              '-'
          ),
          '^([0123456789abcdefABCDEF]{32})$',
          --Case-sensitive
          'c'
      ) THEN 1
      ELSE 0
  END;
  
EXCEPTION
WHEN OTHERS THEN
  
  RETURN 0;
  
END;
/

/*
--test
SELECT IS_UUID('moo')
FROM DUAL;

SELECT IS_UUID('2D17228F687C4CCEA04A922A9EFF0E07')
FROM DUAL;

--Letter i in third position
SELECT IS_UUID('2DI7228F687C4CCEA04A922A9EFF0E07')
FROM DUAL;

--curly brackets
SELECT IS_UUID('{A94C7203-55B0-4841-B48A-DACC35B1154F}')
FROM DUAL;
*/