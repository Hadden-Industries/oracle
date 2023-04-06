CREATE OR REPLACE
FUNCTION PARSE_TELEPHONE_NUMBER
(
    numberToParse IN VARCHAR2,
    defaultRegion IN VARCHAR2 DEFAULT LIBPHONENUMBER.g_defaultRegion
)
RETURN T_TELEPHONENUMBERS PIPELINED
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    rTelephoneNumber T_TELEPHONENUMBER := T_TELEPHONENUMBER(NULL, NULL, NULL);
    
BEGIN
    
    IF LIBPHONENUMBER.isValidNumber(numberToParse, defaultRegion) = 1 THEN
    
        rTelephoneNumber.CountryCode             := LIBPHONENUMBER.getCountryCode(numberToParse, defaultRegion);
        rTelephoneNumber.NationalDestinationCode := LIBPHONENUMBER.getNationalDestinationCode(numberToParse, defaultRegion);
        rTelephoneNumber.SubscriberNumber        := LIBPHONENUMBER.getSubscriberNumber(numberToParse, defaultRegion);
    
    END IF;
    
    PIPE ROW (rTelephoneNumber);
    
END;
/