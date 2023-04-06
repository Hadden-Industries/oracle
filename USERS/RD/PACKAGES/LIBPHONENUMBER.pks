CREATE OR REPLACE
PACKAGE LIBPHONENUMBER
AS

    g_defaultRegion VARCHAR2(2 BYTE) := 'GB'; 

    --FUNCTION IS_GEO_ENTITY(arg0 VARCHAR) RETURN NUMBER AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.internal.GeoEntityUtility.isGeoEntity(java.lang.String ) return boolean ';
    --FUNCTION IS_GEO_ENTITY(arg0 NUMBER) RETURN NUMBER AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.internal.GeoEntityUtility.isGeoEntity(int ) return boolean ';
    FUNCTION GET_COUNTRY_MOBILE_TOKEN(arg0 NUMBER) RETURN VARCHAR AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.PhoneNumberUtil.getCountryMobileToken(int ) return java.lang.String ';

    FUNCTION canBeInternationallyDialled(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION canBeInternationallyDialled(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.canBeInternationallyDialled(java.lang.String, java.lang.String) return boolean';
    
    FUNCTION getCountryCode(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getCountryCode(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getCountryCode(java.lang.String, java.lang.String) return int';
    
    FUNCTION getLengthOfNationalDestinationCode(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getLengthOfNationalDestinationCode(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getLengthOfNationalDestinationCode(java.lang.String, java.lang.String) return int';

    FUNCTION getNationalDestinationCode(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2 DEFAULT g_defaultRegion) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getNationalSignificantNumber(numberToParse IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getNationalSignificantNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getNationalSignificantNumber(java.lang.String, java.lang.String) return java.lang.String';
    
    FUNCTION getNumberType(numberToParse IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getNumberType(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getNumberType(java.lang.String, java.lang.String) return java.lang.String';
    
    FUNCTION getRegionCodeForCountryCode(countryCallingCode IN NUMBER) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getRegionCodeForCountryCode(int) return java.lang.String';
    
    FUNCTION getRegionCodeForNumber(numberToParse IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION getRegionCodeForNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getRegionCodeForNumber(java.lang.String, java.lang.String) return java.lang.String';
    
    FUNCTION getSubscriberNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2 DEFAULT g_defaultRegion) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isNANPACountry(regionCode IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isNANPACountry(java.lang.String) return boolean';
    
    FUNCTION isNumberGeographical(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isNumberGeographical(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isNumberGeographical(java.lang.String, java.lang.String) return boolean';
    
    FUNCTION isValidNumber(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isValidNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isValidNumber(java.lang.String, java.lang.String) return boolean';
END;
/