CREATE OR REPLACE
FUNCTION GET_EMAILS
RETURN VARCHAR2
PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    vEmail VARCHAR2(4000 BYTE) := '';
    
BEGIN
    
    SELECT LISTAGG(Email, ';') WITHIN GROUP (ORDER BY Email) AS Recipient
    INTO vEmail
    FROM
    (
        SELECT Email
        FROM
        (
            SELECT C.LocalPart
            || '@'
            || C.Subdomains
            || '.'
            || LOWER(C.RootZoneDataBase_ID) AS Email,
            --Order by Person_ID in case same name exists for someone else
            ROW_NUMBER() OVER (ORDER BY B.Person_ID, B.Rank) AS RN
            FROM (EMAILADDRESS#PERSON AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE)) B
            INNER JOIN EMAILADDRESS C
                ON B.EmailAddress_UUID = C.UUID
            WHERE B.Person_ID = 1
        )
        WHERE RN = 1
    );
    
    RETURN vEmail;
    
EXCEPTION
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT GET_EMAILS
FROM DUAL;
*/