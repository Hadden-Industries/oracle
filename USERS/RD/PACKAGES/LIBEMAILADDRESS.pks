CREATE OR REPLACE
PACKAGE LIBEMAILADDRESS
AS
    --https://github.com/bbottema/email-rfc2822-validator

    --https://github.com/bbottema/email-rfc2822-validator/blob/master/src/main/java/org/hazlewood/connor/bottema/emailaddress/EmailAddressCriteria.java
    /*
    Defines a set of restriction flags for email address validation. To remain completely true to RFC 2822, all flags should be set to true.
    */
    ALLOW_DOMAIN_LITERALS           CONSTANT VARCHAR2(255 CHAR) := 'ALLOW_DOMAIN_LITERALS'; --This criteria changes the behavior of the domain parsing. If included, the parser will allow 2822 domains, which include single-level domains (e.g. bob@localhost) as well as domain literals
    ALLOW_QUOTED_IDENTIFIERS        CONSTANT VARCHAR2(255 CHAR) := 'ALLOW_QUOTED_IDENTIFIERS'; --This criteria states that as per RFC 2822, quoted identifiers are allowed (using quotes and angle brackets around the raw address)
    ALLOW_DOT_IN_A_TEXT             CONSTANT VARCHAR2(255 CHAR) := 'ALLOW_DOT_IN_A_TEXT'; --This criteria allows '.' to appear in atext (note: only atext which appears in the 2822 'name-addr' part of the address, not the other instances)
    ALLOW_SQUARE_BRACKETS_IN_A_TEXT CONSTANT VARCHAR2(255 CHAR) := 'ALLOW_SQUARE_BRACKETS_IN_A_TEXT'; --This criteria allows '[' or ']' to appear in atext. Not very useful, maybe, but there it is.
    ALLOW_PARENS_IN_LOCALPART       CONSTANT VARCHAR2(255 CHAR) := 'ALLOW_PARENS_IN_LOCALPART'; --This criteria allows as per RFC 2822 ')' or '(' to appear in quoted versions of the localpart (they are never allowed in unquoted versions)

    g_defaultEmailAddressCriteria   CONSTANT VARCHAR2(255 CHAR) := 'RFC_COMPLIANT';
    
    FUNCTION getDomain(emailaddress IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.emailaddress.getDomain(java.lang.String) return java.lang.String';
    
    FUNCTION getLocalPart(emailaddress IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.emailaddress.getLocalPart(java.lang.String) return java.lang.String';
    
    FUNCTION getInternetAddressGetAddress(emailaddress IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.emailaddress.getInternetAddressGetAddress(java.lang.String) return java.lang.String';
    
    FUNCTION isValid(emailaddress IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.emailaddress.isValid(java.lang.String) return boolean';
    
    FUNCTION isValidStrict(emailaddress IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.emailaddress.isValidStrict(java.lang.String) return boolean';
    
END;
/