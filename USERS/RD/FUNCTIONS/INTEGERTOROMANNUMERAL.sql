CREATE OR REPLACE
FUNCTION INTEGERTOROMANNUMERAL(gInteger IN INTEGER)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    i PLS_INTEGER := gInteger;
    vReturn VARCHAR2(4000 BYTE) := '';
    
BEGIN
    
    IF (i <= 0) THEN
        
        RETURN NULL;
        
    END IF;
    
    WHILE (i >= 1000) LOOP
        
        i := i - 1000;
        
        vReturn := vReturn || 'M';
        
    END LOOP;
    
    IF (i >= 900) THEN
        
        i := i - 900;
        
        vReturn := vReturn || 'C' || 'M';
        
    END IF;
    
    IF (i >= 500) THEN
        
        i := i - 500;
        
        vReturn := vReturn || 'D';
        
    END IF;
    
    IF (i >= 400) THEN
        
        i := i - 400;
        
        vReturn := vReturn || 'C' || 'D';
        
    END IF;
    
    WHILE (i >= 100) LOOP
        
        i := i - 100;
        
        vReturn := vReturn || 'C';
        
    END LOOP;
    
    IF (i >= 90) THEN
        
        i := i - 90;
        
        vReturn := vReturn || 'X' || 'C';
        
    END IF;
    
    IF (i >= 50) THEN
        
        i := i - 50;
        
        vReturn := vReturn || 'L';
        
    END IF;
    
    IF (i >= 40) THEN
        
        i := i - 40;
        
        vReturn := vReturn || 'X' || 'L';
        
    END IF;
    
    WHILE (i >= 10) LOOP
        
        i := i - 10;
        
        vReturn := vReturn || 'X';
        
    END LOOP;
    
    IF (i >= 9) THEN
        
        i := i - 9;
        
        vReturn := vReturn || 'I' || 'X';
        
    END IF;
    
    IF (i >= 5) THEN
        
        i := i - 5;
        
        vReturn := vReturn || 'V';
        
    END IF;
    
    IF (i >= 4) THEN
        
        i := i - 4;
        
        vReturn := vReturn || 'I' || 'V';
        
    END IF;
    
    WHILE (i > 0) LOOP
        
        i := i - 1;
        
        vReturn := vReturn || 'I';
        
    END LOOP;
    
    RETURN vReturn;
    
END;
/

/*
--test
SELECT INTEGERTOROMANNUMERAL(0) AS Num
FROM DUAL;

SELECT INTEGERTOROMANNUMERAL(1666) AS Num
FROM DUAL;
*/