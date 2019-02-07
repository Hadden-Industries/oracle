CREATE OR REPLACE
FUNCTION PARSEEMAILADDRESS(gEmail IN VARCHAR2)
RETURN T_EMAILADDRESSES PIPELINED
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    --Disregard trailing
    vEmailAddress VARCHAR2(256 BYTE) := RTRIM
    (
        TRIM
        (
            --Remove display-name if it exists
            CASE
                WHEN INSTR(gEmail, '<') > 0 THEN SUBSTR
                (
                    gEmail,
                    INSTR(gEmail, '<') + 1,
                    --last instance of closing brace
                    INSTR(gEmail, '>', -1) - INSTR(gEmail, '<') - 1
                )
                ELSE gEmail
            END
        ),
        --period
        '.'
    );
    rEmailAddress T_EMAILADDRESS := T_EMAILADDRESS(NULL, NULL, NULL);
    
BEGIN
    
    BEGIN
        
        SELECT ID AS RootZoneDatabase_ID
        INTO rEmailAddress.RootZoneDatabase_ID
        FROM ROOTZONEDATABASE
        WHERE ID = UPPER
        (
            SUBSTRB
            (
                vEmailAddress,
                INSTRB(vEmailAddress, '.', -1, 1) + 1
            )
        );
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        rEmailAddress.RootZoneDatabase_ID := '';
        
    END;
    
    rEmailAddress.LocalPart := LOWER
    (
        SUBSTRB
        (
            vEmailAddress,
            1,
            INSTRB(vEmailAddress, '@', -1, 1) - 1
        )
    );
    
    rEmailAddress.SubDomains := LOWER
    (
        SUBSTRB
        (
            vEmailAddress,
            INSTRB(vEmailAddress, '@', -1, 1) + 1,
            INSTRB(vEmailAddress, '.', -1, 1) - INSTRB(vEmailAddress, '@', -1, 1) - 1
        )
    );
    
    PIPE ROW (rEmailAddress);
    
END;
/

/*
--test
SELECT A.Email AS "Email Address",
B.RootZoneDatabase_ID,
B.LocalPart,
B.SubDomains
FROM
(
    SELECT 'maksym.shostak@haddenindustries.com' AS Email FROM DUAL UNION ALL
    SELECT '"Jym" <info@jym.fit>' AS Email FROM DUAL UNION ALL
    SELECT 'local@part@hmrc.gov.uk.' AS Email FROM DUAL UNION ALL
    SELECT '"Jam" <local@part@hmrc.gov.uk.>' AS Email FROM DUAL UNION ALL
    SELECT '"Abc@def"@example.com' AS Email FROM DUAL
) A
CROSS JOIN TABLE
(
    PARSEEMAILADDRESS(A.Email)
) B;
*/