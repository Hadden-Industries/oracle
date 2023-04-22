CREATE OR REPLACE
PACKAGE LIBPHONENUMBER
AS
    --https://www.javadoc.io/doc/com.googlecode.libphonenumber/libphonenumber/latest/com/google/i18n/phonenumbers/PhoneNumberUtil.html

    --https://www.javadoc.io/static/com.googlecode.libphonenumber/libphonenumber/8.13.9/com/google/i18n/phonenumbers/PhoneNumberUtil.Leniency.html
    /*
    Leniency when finding potential phone numbers in text segments. The levels here are ordered in increasing strictness.
    */
    EXACT_GROUPING  CONSTANT VARCHAR2(255 CHAR) := 'EXACT_GROUPING'; --Phone numbers accepted are valid and are grouped in the same way that we would have formatted it, or as a single block. For example, a US number written as "650 2530000" is not accepted at this leniency level, whereas "650 253 0000" or "6502530000" are. Numbers with more than one '/' symbol are also dropped at this level. Warning: This level might result in lower coverage especially for regions outside of country code "+1". If you are not sure about which level to use, email the discussion group libphonenumber-discuss@googlegroups.com.
    POSSIBLE        CONSTANT VARCHAR2(255 CHAR) := 'POSSIBLE'; --Phone numbers accepted are possible, but not necessarily valid.
    STRICT_GROUPING CONSTANT VARCHAR2(255 CHAR) := 'STRICT_GROUPING'; --Phone numbers accepted are valid and are grouped in a possible way for this locale. For example, a US number written as "65 02 53 00 00" and "650253 0000" are not accepted at this leniency level, whereas "650 253 0000", "650 2530000" or "6502530000" are. Numbers with more than one '/' symbol in the national significant number are also dropped at this level. Warning: This level might result in lower coverage especially for regions outside of country code "+1". If you are not sure about which level to use, email the discussion group libphonenumber-discuss@googlegroups.com.
    VALID           CONSTANT VARCHAR2(255 CHAR) := 'VALID'; --Phone numbers accepted are possible and valid. Numbers written in national format must have their national-prefix present if it is usually written for a number of this type.

    --https://www.javadoc.io/static/com.googlecode.libphonenumber/libphonenumber/8.13.9/com/google/i18n/phonenumbers/PhoneNumberUtil.MatchType.html
    /*
    isNumberMatch
    Returns EXACT_MATCH if the country_code, NSN, presence of a leading zero for Italian numbers and any extension present are the same.
    Returns NSN_MATCH if either or both has no region specified, and the NSNs and extensions are the same.
    Returns SHORT_NSN_MATCH if either or both has no region specified, or the region specified is the same, and one NSN could be a shorter version of the other number.
    This includes the case where one has an extension specified, and the other does not. Returns NO_MATCH otherwise.
    For example, the numbers +1 345 657 1234 and 657 1234 are a SHORT_NSN_MATCH. The numbers +1 345 657 1234 and 345 657 are a NO_MATCH.
    */
    EXACT_MATCH     CONSTANT VARCHAR2(255 CHAR) := 'EXACT_MATCH';
    NO_MATCH        CONSTANT VARCHAR2(255 CHAR) := 'NO_MATCH';
    NOT_A_NUMBER    CONSTANT VARCHAR2(255 CHAR) := 'NOT_A_NUMBER';
    NSN_MATCH       CONSTANT VARCHAR2(255 CHAR) := 'NSN_MATCH';
    SHORT_NSN_MATCH CONSTANT VARCHAR2(255 CHAR) := 'SHORT_NSN_MATCH';

    --https://www.javadoc.io/static/com.googlecode.libphonenumber/libphonenumber/8.13.9/com/google/i18n/phonenumbers/PhoneNumberUtil.PhoneNumberFormat.html
    /*
    INTERNATIONAL and NATIONAL formats are consistent with the definition in ITU-T Recommendation E.123.
    However we follow local conventions such as using '-' instead of whitespace as separators.
    For example, the number of the Google Switzerland office will be written as "+41 44 668 1800" in INTERNATIONAL format, and as "044 668 1800" in NATIONAL format.
    E164 format is as per INTERNATIONAL format but with no formatting applied, e.g. "+41446681800".
    RFC3966 is as per INTERNATIONAL format, but with all spaces and other separating symbols replaced with a hyphen, and with any phone number extension appended with ";ext=".
    It also will have a prefix of "tel:" added, e.g. "tel:+41-44-668-1800".
    Note: If you are considering storing the number in a neutral format, you are highly advised to use the PhoneNumber class.
    */
    E164            CONSTANT VARCHAR2(255 CHAR) := 'E164';
    INTERNATIONAL   CONSTANT VARCHAR2(255 CHAR) := 'INTERNATIONAL';
    NATIONAL        CONSTANT VARCHAR2(255 CHAR) := 'NATIONAL';
    RFC3966         CONSTANT VARCHAR2(255 CHAR) := 'RFC3966';
    
    --https://www.javadoc.io/static/com.googlecode.libphonenumber/libphonenumber/8.13.9/com/google/i18n/phonenumbers/PhoneNumberUtil.PhoneNumberType.html
    FIXED_LINE              CONSTANT VARCHAR2(255 CHAR) := 'FIXED_LINE';
    FIXED_LINE_OR_MOBILE    CONSTANT VARCHAR2(255 CHAR) := 'FIXED_LINE_OR_MOBILE';
    MOBILE                  CONSTANT VARCHAR2(255 CHAR) := 'MOBILE';
    PAGER                   CONSTANT VARCHAR2(255 CHAR) := 'PAGER';
    PERSONAL_NUMBER         CONSTANT VARCHAR2(255 CHAR) := 'PERSONAL_NUMBER';
    PREMIUM_RATE            CONSTANT VARCHAR2(255 CHAR) := 'PREMIUM_RATE';
    SHARED_COST             CONSTANT VARCHAR2(255 CHAR) := 'SHARED_COST';
    TOLL_FREE               CONSTANT VARCHAR2(255 CHAR) := 'TOLL_FREE';
    UAN                     CONSTANT VARCHAR2(255 CHAR) := 'UAN';
    UNKNOWN                 CONSTANT VARCHAR2(255 CHAR) := 'UNKNOWN';
    VOICEMAIL               CONSTANT VARCHAR2(255 CHAR) := 'VOICEMAIL';
    VOIP                    CONSTANT VARCHAR2(255 CHAR) := 'VOIP';

    --https://www.javadoc.io/static/com.googlecode.libphonenumber/libphonenumber/8.13.9/com/google/i18n/phonenumbers/PhoneNumberUtil.ValidationResult.html
    INVALID_COUNTRY_CODE    CONSTANT VARCHAR2(255 CHAR) := 'INVALID_COUNTRY_CODE'; --The number has an invalid country calling code.
    INVALID_LENGTH          CONSTANT VARCHAR2(255 CHAR) := 'INVALID_LENGTH'; --The number is longer than the shortest valid numbers for this region, shorter than the longest valid numbers for this region, and does not itself have a number length that matches valid numbers for this region.
    IS_POSSIBLE             CONSTANT VARCHAR2(255 CHAR) := 'IS_POSSIBLE'; --The number length matches that of valid numbers for this region.
    IS_POSSIBLE_LOCAL_ONLY  CONSTANT VARCHAR2(255 CHAR) := 'IS_POSSIBLE_LOCAL_ONLY'; --The number length matches that of local numbers for this region only (i.e.
    TOO_LONG                CONSTANT VARCHAR2(255 CHAR) := 'TOO_LONG'; --The number is longer than all valid numbers for this region.
    TOO_SHORT               CONSTANT VARCHAR2(255 CHAR) := 'TOO_SHORT'; --The number is shorter than all valid numbers for this region.

    g_defaultNumberFormatString VARCHAR2(255 CHAR)  := INTERNATIONAL;
    g_defaultNumberTypeString   VARCHAR2(255 CHAR)  := UNKNOWN;
    g_defaultRegion             VARCHAR2(2 BYTE)    := 'GB';

    --FUNCTION IS_GEO_ENTITY(arg0 VARCHAR) RETURN NUMBER AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.internal.GeoEntityUtility.isGeoEntity(java.lang.String ) return boolean ';
    --FUNCTION IS_GEO_ENTITY(arg0 NUMBER) RETURN NUMBER AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.internal.GeoEntityUtility.isGeoEntity(int ) return boolean ';
    FUNCTION GET_COUNTRY_MOBILE_TOKEN(arg0 NUMBER) RETURN VARCHAR AS LANGUAGE JAVA NAME 'com.google.i18n.phonenumbers.PhoneNumberUtil.getCountryMobileToken(int ) return java.lang.String ';

    FUNCTION canBeInternationallyDialled(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION canBeInternationallyDialled(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.canBeInternationallyDialled(java.lang.String, java.lang.String) return boolean';
    
    FUNCTION format(numberToParse IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION format(numberToParse IN VARCHAR2, numberFormatString IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION format(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2, numberFormatString IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.format(java.lang.String, java.lang.String, java.lang.String) return java.lang.String';
    
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
    
    FUNCTION getSupportedRegions RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.getSupportedRegions() return java.lang.String';
    
    FUNCTION isAlphaNumber(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isAlphaNumber(java.lang.String) return boolean';
    
    FUNCTION isNANPACountry(regionCode IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isNANPACountry(java.lang.String) return boolean';
    
    FUNCTION isNumberGeographical(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isNumberGeographical(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isNumberGeographical(java.lang.String, java.lang.String) return boolean';
    
    FUNCTION isPossibleNumberWithReason(numberToParse IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isPossibleNumberWithReason(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isPossibleNumberWithReason(java.lang.String, java.lang.String) return java.lang.String';
    
    FUNCTION isValidNumber(numberToParse IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE;
    
    FUNCTION isValidNumber(numberToParse IN VARCHAR2, defaultRegion IN VARCHAR2) RETURN NUMBER DETERMINISTIC PARALLEL_ENABLE AS LANGUAGE JAVA NAME
    'com.haddenindustries.oracle.phonenumber.isValidNumber(java.lang.String, java.lang.String) return boolean';
END;
/