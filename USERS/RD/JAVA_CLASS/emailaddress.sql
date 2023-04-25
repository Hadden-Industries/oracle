CREATE OR REPLACE
AND RESOLVE
JAVA SOURCE NAMED emailaddress
AS

    package com.haddenindustries.oracle;

    import java.lang.*;
    import java.util.*;
    import javax.mail.internet.InternetAddress;
    import org.hazlewood.connor.bottema.emailaddress.*;

    public class emailaddress
    {
        public static String[] getAddressParts(String emailaddress)
        {
            return EmailAddressParser.getAddressParts(emailaddress, EmailAddressCriteria.RFC_COMPLIANT, false);
        }
        
        public static String[] getAddressParts(String emailaddress, boolean extractCfwsPersonalNames)
        {
            return EmailAddressParser.getAddressParts(emailaddress, EmailAddressCriteria.RFC_COMPLIANT, extractCfwsPersonalNames);
        }
        
        public static String[] getAddressParts(String emailaddress, EnumSet<EmailAddressCriteria> criteria, boolean extractCfwsPersonalNames)
        {
            return EmailAddressParser.getAddressParts(emailaddress, criteria, extractCfwsPersonalNames);
        }
        
        public static String getInternetAddressGetAddress(String emailaddress)
        {
            String val = "";

            try
            {
                InternetAddress internetAddress = EmailAddressParser.getInternetAddress(emailaddress, EmailAddressCriteria.RFC_COMPLIANT, false);
                
                val =  internetAddress.getAddress();
            }
            catch (Exception e)
            {
                val = "";
            }

            return val;
        }
        
        public static String getDomain(String emailaddress)
        {
            return EmailAddressParser.getDomain(emailaddress, EmailAddressCriteria.RFC_COMPLIANT, false);
        }
        
        public static String getLocalPart(String emailaddress)
        {
            return EmailAddressParser.getLocalPart(emailaddress, EmailAddressCriteria.RFC_COMPLIANT, false);
        }
        
        public static boolean isValid(String emailaddress)
        {
            return EmailAddressValidator.isValid(emailaddress);
        }
        
        public static boolean isValid(String emailaddress, EnumSet<EmailAddressCriteria> criteria)
        {
            return EmailAddressValidator.isValid(emailaddress, criteria);
        }
        
        public static boolean isValidStrict(String emailaddress)
        {
            return EmailAddressValidator.isValidStrict(emailaddress);
        }
    }
/

SHOW ERRORS