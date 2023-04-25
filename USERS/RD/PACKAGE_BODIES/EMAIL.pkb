CREATE OR REPLACE 
PACKAGE BODY EMAIL
AS
    
    --Global package variables
    gMailHost       CONSTANT CHAR(14 BYTE)             := 'smtp.gmail.com';
    gMailPort       CONSTANT PLS_INTEGER               := 465;
    gWalletPath     ORACLEDATABASEWALLET.Path%TYPE     := '';
    gWalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
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
    ) AS
        
        --Error variable
        vError               VARCHAR2(255 BYTE) := NULL;
        
        --Program variables
        xConnection          UTL_SMTP.CONNECTION;
        
        nOffset              SIMPLE_INTEGER := 1;
        nBodyLength          SIMPLE_INTEGER := 0;
        nAttachmentLength    SIMPLE_INTEGER := 0;
        
        l_username           VARCHAR2(255 CHAR) := '';
        l_password           VARCHAR2(255 CHAR) := '';
        
        --Boundary variables
        vBoundaryEmail       CHAR(36 BYTE) := '';
        vBoundaryContent     CHAR(40 BYTE) := '';
        vBoundaryTermination CHAR(42 BYTE) := '';
        
    BEGIN
        
        SELECT Username,
        Password
        INTO l_username,
        l_password
        FROM
        (
            SELECT /*+OPT_ESTIMATE(TABLE A ROWS=1)*/
            C.Key,
            C.Value
            FROM DNSDOMAIN AS OF PERIOD FOR TRANSACTION_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) A
            INNER JOIN EMAILADDRESS AS OF PERIOD FOR TRANSACTION_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) B
                ON A.ProductOrServiceIndiv_ID = B.DNSDomain_ProductOrServiceIndiv_ID
            INNER JOIN PRODUCTORSERVICEINDIVCREDENTIAL AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) C
                ON B.ProductOrServiceIndiv_ID = C.ProductOrServiceIndiv_ID
            WHERE A.FQDN = LIBEMAILADDRESS.getDomain(Sender) || '.'
            AND B.LocalPart = LIBEMAILADDRESS.getLocalPart(Sender)
        )
        PIVOT 
        (
            MIN(Value)
            FOR Key IN
            (
                'Username' AS USERNAME,
                'Password' AS PASSWORD
            )
        );
        
        IF (l_username IS NULL OR l_password IS NULL) THEN
        
            RAISE NO_DATA_FOUND;
        
        END IF;
        
        xConnection := UTL_SMTP.Open_Connection
        (
            host => gMailHost,
            port => gMailPort,
            tx_timeout => 61,
            wallet_path => gWalletPath,
            wallet_password => gWalletPassword,
            secure_connection_before_smtp => TRUE
        );
        
        UTL_SMTP.Ehlo(xConnection, gMailHost);
        
        UTL_SMTP.Auth
        (
            c        => xConnection,
            username => l_username,
            password => l_password,
            schemes  => UTL_SMTP.All_Schemes
        );
        
        UTL_SMTP.Mail(xConnection, sender);
        
        --TO
        FOR C IN
        (
            SELECT Text AS EmailAddress
            FROM TABLE
            (
                SPLIT(Recipient, ';')
            )
            WHERE INSTRB(Text, '@') > 0
        ) LOOP
            
            UTL_SMTP.Rcpt(xConnection, C.EmailAddress);
            
        END LOOP;
        
        --CC
        FOR C IN
        (
            SELECT Text AS EmailAddress
            FROM TABLE
            (
                SPLIT(CC, ';')
            )
            WHERE INSTRB(Text, '@') > 0
        ) LOOP
            
            UTL_SMTP.Rcpt(xConnection, C.EmailAddress);
            
        END LOOP;
        
        --BCC
        FOR C IN
        (
            SELECT Text AS EmailAddress
            FROM TABLE
            (
                SPLIT(BCC, ';')
            )
            WHERE INSTRB(Text, '@') > 0
        ) LOOP
            
            UTL_SMTP.Rcpt(xConnection, C.EmailAddress);
            
        END LOOP;
        
        UTL_SMTP.Open_Data(xConnection);
        
        --Write header details
        UTL_SMTP.Write_Data(xConnection, 'From: ' || Sender || UTL_TCP.CRLF);
        
        IF recipient IS NOT NULL THEN
            
            UTL_SMTP.Write_Data(xConnection, 'To: ' || Recipient || UTL_TCP.CRLF);
            
        END IF;
        
        IF cc IS NOT NULL THEN
            
            UTL_SMTP.Write_Data(xConnection, 'CC: ' || CC || UTL_TCP.CRLF);
            
        END IF;
        
        IF bcc IS NOT NULL THEN
            
            UTL_SMTP.Write_Data(xConnection, 'BCC: ' || BCC || UTL_TCP.CRLF);
            
        END IF;
        
        UTL_SMTP.Write_Data(xConnection, 'Subject: ' || Subject || UTL_TCP.CRLF);
        
        IF Attachments IS NOT NULL THEN
            
            vBoundaryEmail       := UUID_VER4;
            vBoundaryContent     := '--' || vBoundaryEmail || UTL_TCP.CRLF;
            vBoundaryTermination := '--' || vBoundaryEmail || '--' || UTL_TCP.CRLF;
            
            UTL_SMTP.Write_Data(xConnection, 'Content-Type: multipart/mixed;' || UTL_TCP.CRLF);
            
            UTL_SMTP.Write_Data(xConnection, ' boundary="' || vBoundaryEmail || '"' || UTL_TCP.CRLF || UTL_TCP.CRLF);
            
            UTL_SMTP.Write_Data(xConnection, 'This is a multi-part message in MIME format.' || UTL_TCP.CRLF);
            
            UTL_SMTP.Write_Data(xConnection, UTL_TCP.CRLF || UTL_TCP.CRLF || UTL_TCP.CRLF || vBoundaryContent);
            
        END IF;
        
        --Body of message
        IF Msg IS NOT NULL THEN
            
            UTL_SMTP.Write_Data(xConnection, 'Content-Type: ' || ContentType || '; charset=utf-8; format=flowed' || UTL_TCP.CRLF);
            
            UTL_SMTP.Write_Data(xConnection, 'Content-Transfer-Encoding: 7bit' || UTL_TCP.CRLF || UTL_TCP.CRLF);
            
            --Send email body
            nBodyLength := DBMS_LOB.GetLength(lob_loc => Msg);
            
            IF nBodyLength > 0 THEN
                
                WHILE nOffset < nBodyLength LOOP
                    
                    IF (nBodyLength - nOffset) >= 4095 THEN
                        
                        UTL_SMTP.Write_Raw_Data
                        (
                            xConnection,
                            UTL_RAW.Cast_To_Raw
                            (
                                DBMS_LOB.Substr(Msg, 4095, nOffset)
                            )
                        );
                        
                        nOffset := nOffset + 4095;
                        
                    ELSE
                        
                        UTL_SMTP.Write_Raw_Data
                        (
                            xConnection,
                            UTL_RAW.Cast_To_Raw
                            (
                                DBMS_LOB.Substr(Msg, nBodyLength - nOffset + 1, nOffset)
                            )
                        );
                        
                        nOffset := nBodyLength;
                        
                    END IF;
                    
                END LOOP;
                
            END IF;
            
        END IF;
        
        --Add Attachments
        IF Attachments IS NOT NULL THEN
            
            FOR idx IN Attachments.list.FIRST .. Attachments.list.LAST LOOP
                
                IF Attachments.list(idx).length IS NOT NULL THEN
                    
                    nAttachmentLength := Attachments.list(idx).length;
                    
                    IF nAttachmentLength > 0 THEN
                        
                        UTL_SMTP.Write_Data(xConnection, UTL_TCP.CRLF);
                        UTL_SMTP.Write_Data(xConnection, vBoundaryContent);
                        UTL_SMTP.Write_Data(xConnection, 'Content-Type: ' || Attachments.list(idx).ContentType || '; charset=utf-8;' || UTL_TCP.CRLF);
                        UTL_SMTP.Write_Data(xConnection, ' name="' || LOWER(Attachments.list(idx).FileName) || '"' || UTL_TCP.CRLF);
                        UTL_SMTP.Write_Data(xConnection, 'Content-Transfer-Encoding: 7bit' || UTL_TCP.CRLF);
                        UTL_SMTP.Write_Data(xConnection, 'Content-Disposition: attachment;' || UTL_TCP.CRLF);
                        UTL_SMTP.Write_Data(xConnection, ' filename="' || LOWER(Attachments.list(idx).FileName) || '"' || UTL_TCP.CRLF);
                        
                        nOffset := 1;
                        
                        --Write the CLOB
                        WHILE nOffset < nAttachmentLength LOOP
                            
                            IF (nAttachmentLength - nOffset) >= 4095 THEN
                                
                                UTL_SMTP.Write_Raw_Data
                                (
                                    xConnection,
                                    UTL_RAW.Cast_To_Raw
                                    (
                                        DBMS_LOB.Substr
                                        (
                                            Attachments.list(idx).attachment,
                                            4095,
                                            nOffset
                                        )
                                    )
                                );
                                
                                nOffset := nOffset + 4095;
                                
                            ELSE
                                
                                UTL_SMTP.Write_Raw_Data
                                (
                                    xConnection,
                                    UTL_RAW.Cast_To_Raw
                                    (
                                        DBMS_LOB.Substr
                                        (
                                            Attachments.list(idx).attachment,
                                            nAttachmentLength - nOffset + 1,
                                            nOffset
                                        )
                                    )
                                );
                                
                                nOffset := nAttachmentLength;
                                
                            END IF;
                            
                        END LOOP;
                        
                        UTL_SMTP.Write_Data(xConnection, UTL_TCP.CRLF);
                        
                    END IF;
                    
                END IF;
                
            END LOOP;
            
            UTL_SMTP.Write_Data(xConnection, vBoundaryTermination);
            
        END IF;
        
        UTL_SMTP.Close_Data(xConnection);
        
        UTL_SMTP.Quit(xConnection);
        
    EXCEPTION
    WHEN OTHERS THEN
        
        vError := SUBSTRB(SQLErrM, 1, 255);
        
        DBMS_OUTPUT.Put_Line(vError);
        
    END SEND;


BEGIN
    
    BEGIN
        
        DBMS_APPLICATION_INFO.Set_Module
        (
            module_name => 'EMAIL',
            action_name => 'Retrieving wallet information'
        );
        
        SELECT Path,
        Password
        INTO gWalletPath,
        gWalletPassword
        FROM ORACLEDATABASEWALLET
        WHERE Path IS NOT NULL
        AND Password IS NOT NULL;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
END;
/