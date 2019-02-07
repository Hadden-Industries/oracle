CREATE OR REPLACE
FUNCTION ISIN_CHECK_DIGIT(pISIN IN VARCHAR2)
RETURN NUMBER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    s NUMBER := 0;
    a NUMBER := 2;
    c NUMBER := 0;
    
BEGIN
    
    IF (LENGTHB(pISIN) <> 11) THEN
        
        RETURN -1;
        
    END IF;
    
    FOR i IN REVERSE 1..LENGTHB(pISIN) LOOP
        
        c := ASCII(SUBSTR(pISIN, i, 1));
        
        IF c > ASCII('9') THEN
            
            c := c - (ASCII('A')-10);
            s := s + TRUNC((3 - A) * TRUNC(c / 10) + a * c + (a - 1) * (TRUNC(MOD(c,10))) / 5);
            
        ELSE
            
            c  := c - ASCII('0');
            s :=  s + (a * c + (a - 1) * TRUNC(c / 5));
            a := 3 - a;
            
        END IF;
        
    END LOOP;
    
    s := TRUNC(MOD(s, 10));
    
    RETURN TRUNC(MOD(10 - TRUNC(MOD(s, 10)), 10));
    
END;
/