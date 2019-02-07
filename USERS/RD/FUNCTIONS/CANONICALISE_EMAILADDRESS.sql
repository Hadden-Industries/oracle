CREATE OR REPLACE
FUNCTION CANONICALISE_EMAILADDRESS(gEmailAddress T_EMAILADDRESS)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
BEGIN
    
    IF (gEmailAddress.RootZoneDataBase_ID IS NULL
        OR gEmailAddress.LocalPart IS NULL
        OR gEmailAddress.Subdomains IS NULL) THEN
        
        RETURN NULL;
        
    END IF;
    
    RETURN gEmailAddress.LocalPart || '@' || gEmailAddress.Subdomains || '.' || LOWER(gEmailAddress.RootZoneDataBase_ID);
    
END ;
/

/*
--test
SELECT CANONICALISE_EMAILADDRESS(NULL)
FROM DUAL;

SELECT UUID,
RootZoneDataBase_ID,
LocalPart,
Subdomains,
CANONICALISE_EMAILADDRESS
(
    T_EMAILADDRESS(RootZoneDataBase_ID, LocalPart, Subdomains)
) AS Email
FROM EMAILADDRESS;
*/