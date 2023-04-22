CREATE OR REPLACE
PACKAGE BODY LIBPHONENUMBER
AS

    FUNCTION canBeInternationallyDialled(numberToParse IN VARCHAR2)
    RETURN NUMBER
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN canBeInternationallyDialled(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION format(numberToParse IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN format(numberToParse, g_defaultNumberFormatString);
    
    END;
    
    FUNCTION format(numberToParse IN VARCHAR2, numberFormatString IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN format(numberToParse, g_defaultRegion, numberFormatString);
    
    END;
    
    FUNCTION getCountryCode(numberToParse IN VARCHAR2)
    RETURN NUMBER
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN getCountryCode(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION getLengthOfNationalDestinationCode(numberToParse IN VARCHAR2)
    RETURN NUMBER
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN getLengthOfNationalDestinationCode(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION getNationalDestinationCode(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2 DEFAULT g_defaultRegion)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN SUBSTR
        (
            getNationalSignificantNumber(numberToParse, defaultRegion),
            1,
            getLengthOfNationalDestinationCode(numberToParse, defaultRegion)
        );
    
    END;
    
    FUNCTION getNationalSignificantNumber(numberToParse IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN getNationalSignificantNumber(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION getNumberType(numberToParse IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN getNumberType(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION getRegionCodeForNumber(numberToParse IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN getRegionCodeForNumber(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION getSubscriberNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2 DEFAULT g_defaultRegion)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN SUBSTR
        (
            getNationalSignificantNumber(numberToParse, defaultRegion),
            getLengthOfNationalDestinationCode(numberToParse, defaultRegion) + 1
        );
    
    END;
    
    FUNCTION isNumberGeographical(numberToParse IN VARCHAR2)
    RETURN NUMBER
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN isNumberGeographical(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION isPossibleNumberWithReason(numberToParse IN VARCHAR2)
    RETURN VARCHAR2
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN isPossibleNumberWithReason(numberToParse, g_defaultRegion);
    
    END;
    
    FUNCTION isValidNumber(numberToParse IN VARCHAR2)
    RETURN NUMBER
    DETERMINISTIC
    PARALLEL_ENABLE
    AS
    BEGIN
    
        RETURN isValidNumber(numberToParse, g_defaultRegion);
    
    END;

END;
/