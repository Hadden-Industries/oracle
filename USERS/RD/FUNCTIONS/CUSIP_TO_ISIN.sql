CREATE OR REPLACE
FUNCTION CUSIP_TO_ISIN
(
    pCUSIP IN VARCHAR2,
    pCountry_ID CHAR DEFAULT 'USA'
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    CUSIP VARCHAR2(9 BYTE) := '';
    Country_Alpha2 COUNTRY.Alpha2%TYPE := '';
    
BEGIN
    
    IF NOT REGEXP_LIKE(pCUSIP, '^[ABCDEFGHIJKLMNOPQRSTUVWXYZ[:digit:]*@#]{6,8}[[:digit:]]?$') THEN
        
        RETURN NULL;
        
    END IF;
    
    BEGIN
        
        SELECT B.Alpha2
        INTO Country_Alpha2
        FROM NUMBERINGAGENCY A
        INNER JOIN COUNTRY B
            ON A.Country_ID = B.ID
        WHERE A.Country_ID = pCountry_ID
        AND A.NSINAcronym IN ('CINS', 'CUSIP')
        GROUP BY B.Alpha2;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        SELECT Alpha2
        INTO Country_Alpha2
        FROM COUNTRY
        WHERE ID = 'USA';
        
    END;
    
    IF (LENGTHB(pCUSIP) = 9) THEN
        
        IF CUSIP_CHECK_DIGIT(SUBSTRB(pCUSIP, 1, 8)) = SUBSTRB(pCUSIP, -1) THEN
            
            CUSIP := pCUSIP;
            
        ELSE
            
            RETURN NULL; --CUSIP is not valid
            
        END IF;
        
    ELSIF (LENGTHB(pCUSIP) = 8) THEN
        
        CUSIP := pCUSIP || TO_CHAR(CUSIP_CHECK_DIGIT(pCUSIP));
        
    ELSIF (LENGTHB(pCUSIP) = 7) THEN
        
        CUSIP := pCUSIP || '*';
        CUSIP := CUSIP || TO_CHAR(CUSIP_CHECK_DIGIT(CUSIP));
        
    ELSIF (LENGTHB(pCUSIP) = 6) THEN
        
        CUSIP := pCUSIP || '**';
        CUSIP := CUSIP || TO_CHAR(CUSIP_CHECK_DIGIT(CUSIP));
        
    ELSE --if length not between 6 and 9
        
        RETURN NULL;
        
    END IF;
    
    IF INSTR(CUSIP, '*') > 0 THEN
        
        RETURN Country_Alpha2 || CUSIP || '*';
        
    ELSE
        
        RETURN Country_Alpha2 || CUSIP || TO_CHAR(ISIN_CHECK_DIGIT(Country_Alpha2 || CUSIP));
        
    END IF;
    
END;
/