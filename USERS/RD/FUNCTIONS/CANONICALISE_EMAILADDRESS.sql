CREATE OR REPLACE
FUNCTION CANONICALISE_EMAILADDRESS(gEmailAddress T_EMAILADDRESS)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    IF (gEmailAddress.LocalPart IS NULL
        OR gEmailAddress.Domain IS NULL) THEN
        
        RETURN NULL;
        
    END IF;
    
    RETURN gEmailAddress.LocalPart || '@' || RTRIM(gEmailAddress.Domain, '.');
    
END ;
/

/*
--test
SELECT CANONICALISE_EMAILADDRESS(NULL)
FROM DUAL;

SELECT A.ProductOrServiceIndiv_ID,
A.LocalPart,
B.FQDN,
CANONICALISE_EMAILADDRESS
(
    T_EMAILADDRESS(A.LocalPart, B.FQDN)
) AS EmailAddress
FROM EMAILADDRESS A
INNER JOIN DNSDOMAIN B
    ON A.DNSDomain_ProductOrServiceIndiv_ID = B.ProductOrServiceIndiv_ID;
*/