/*
Oracle Wallet Manager
New
Create password
Download base-64 certificate from http://www.geotrust.com/resources/root-certificates/
Trusted certificates->Import the above
Save into directory specified in ORACLEDATABASEWALLET.Path
*/

CREATE OR REPLACE 
PACKAGE EMAIL
AS
    
    PROCEDURE SEND
    (
        Sender IN VARCHAR2,
        Recipient IN VARCHAR2,
        CC IN VARCHAR2 DEFAULT '',
        BCC IN VARCHAR2 DEFAULT '',
        Subject IN VARCHAR2 DEFAULT '',
        Msg IN CLOB DEFAULT NULL,
        Attachments IN T_EMAIL_ATTACHMENTS DEFAULT NULL,
        ContentType IN VARCHAR2 DEFAULT 'text/html'
    );
    
END;
/