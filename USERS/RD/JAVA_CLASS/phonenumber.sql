CREATE OR REPLACE
AND RESOLVE
JAVA SOURCE NAMED phonenumber
AS

    package com.haddenindustries.oracle;

    import java.lang.*;
    import java.util.*;
    import com.google.i18n.phonenumbers.*;

    public class phonenumber
    {
        public static final String DEFAULT_REGION = "GB";
        
        public static boolean canBeInternationallyDialled(String numberToParse, String defaultRegion)
        {
            boolean val = false;
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val = phoneNumberUtil.canBeInternationallyDialled(phoneNumber);
            }
            catch (Exception e)
            {
                val = false;
            }
    
            return val;
        }
        
        public static int getCountryCode(String numberToParse, String defaultRegion)
        {
            int val = 0;

            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val =  phoneNumber.getCountryCode();
            }
            catch (Exception e)
            {
                val = 0;
            }
    
            return val;
        }
        
        public static int getLengthOfNationalDestinationCode(String numberToParse, String defaultRegion)
        {
            int val = 0;
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val =  phoneNumberUtil.getLengthOfNationalDestinationCode(phoneNumber);
            }
            catch (Exception e)
            {
                val = 0;
            }
    
            return val;
        }
        
        public static String getNationalSignificantNumber(String numberToParse, String defaultRegion)
        {
            String val = "";
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val =  phoneNumberUtil.getNationalSignificantNumber(phoneNumber);
            }
            catch (Exception e)
            {
                val = "";
            }
    
            return val;
        }
        
        public static PhoneNumberUtil.PhoneNumberType getNumberType(String numberToParse, String defaultRegion)
        {
            PhoneNumberUtil.PhoneNumberType val = PhoneNumberUtil.PhoneNumberType.UNKNOWN;
            
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val =  phoneNumberUtil.getNumberType(phoneNumber);
            }
            catch (Exception e)
            {
                val = PhoneNumberUtil.PhoneNumberType.UNKNOWN;
            }
    
            return val;
        }
        
        public static String getRegionCodeForCountryCode(int countryCallingCode)
        {
            String val = "";
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                val =  phoneNumberUtil.getRegionCodeForCountryCode(countryCallingCode);
            }
            catch (Exception e)
            {
                val = "";
            }
    
            return val;
        }
        
        public static String getRegionCodeForNumber(String numberToParse, String defaultRegion)
        {
            String val = "";
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val =  phoneNumberUtil.getRegionCodeForNumber(phoneNumber);
            }
            catch (Exception e)
            {
                val = "";
            }
    
            return val;
        }
        
        public static boolean isNANPACountry(String regionCode)
        {
            boolean val = false;
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                val = phoneNumberUtil.isNANPACountry(regionCode);
            }
            catch (Exception e)
            {
                val = false;
            }
    
            return val;
        }
        
        public static boolean isNumberGeographical(String numberToParse, String defaultRegion)
        {
            boolean val = false;
    
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val = phoneNumberUtil.isNumberGeographical(phoneNumber);
            }
            catch (Exception e)
            {
                val = false;
            }
    
            return val;
        }

        public static boolean isValidNumber(String numberToParse, String defaultRegion)
        {
            boolean val = false;
            
            try
            {
                PhoneNumberUtil phoneNumberUtil = PhoneNumberUtil.getInstance();
                
                Phonenumber.PhoneNumber phoneNumber = phoneNumberUtil.parse(numberToParse, defaultRegion);
                
                val = phoneNumberUtil.isValidNumber(phoneNumber);
            }
            catch (Exception e)
            {
                val = false;
            }
    
            return val;
        }
    }
/

SHOW ERRORS