CREATE OR REPLACE
FUNCTION CUSIP_CHECK_DIGIT(pCUSIP IN VARCHAR2)
RETURN NUMBER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    s NUMBER := 0;
    c NUMBER := 0;
    
BEGIN
    
    IF (LENGTHB(pCUSIP) <> 8) THEN
        
        RETURN -1;
        
    END IF;
    
    FOR i IN 1..LENGTHB(pCUSIP) LOOP
        
        c := ASCII(SUBSTRB(pCUSIP, i, 1));
        
        IF c BETWEEN ASCII('A') AND ASCII('Z') THEN
            c := c - (ASCII('A')-10);
        ELSIF c = ASCII('*') THEN
            c := 36;
        ELSIF c = ASCII('@') THEN
            c := 37;
        ELSIF c = ASCII('#') THEN
            c := 38;
        ELSE
            c  := c - ASCII('0');
        END IF;
        
        IF REMAINDER(i - 1, 2) != 0 THEN
            c := 2*c;
        END IF;
        
        s := s + TRUNC((c/10), 0) + MOD(c, 10);
        
    END LOOP;
    
    RETURN MOD(10 - MOD(s, 10), 10);
    
END;
/