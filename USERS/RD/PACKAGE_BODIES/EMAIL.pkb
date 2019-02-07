CREATE OR REPLACE 
PACKAGE BODY EMAIL
AS
    
    --Global package variables
    gMailHost CHAR(14 BYTE) := 'smtp.gmail.com';
    gMailPort PLS_INTEGER := 465;
    gWalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
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
        
        PRAGMA AUTONOMOUS_TRANSACTION;
        
        --Error variable
        vError VARCHAR2(255 BYTE) := NULL;
        
        --Program variables
        vSenderDomain VARCHAR2(4000 BYTE) := '';
        vTableSpace_Status VARCHAR2(30 BYTE) := '';
        xConnection UTL_SMTP.CONNECTION;
        
        nOffset SIMPLE_INTEGER := 1;
        nBodyLength SIMPLE_INTEGER := 0;
        nAttachmentLength SIMPLE_INTEGER := 0;
        
        --Boundary variables
        vBoundaryEmail CONSTANT CHAR(36) := LPAD
        (
            TRUNC
            (
                DBMS_RANDOM.Value('100000000000000000000', '999999999999999999999')
            ),
            36,
            '-'
        );
        vBoundaryContent CONSTANT CHAR(40) := '--' || vBoundaryEmail || UTL_TCP.CRLF;
        vBoundaryTermination CONSTANT CHAR(42) := '--' || vBoundaryEmail || '--' || UTL_TCP.CRLF;
        
    BEGIN
        
        --Check the status of the tablespace that holds the logging table
        SELECT USER_TABLESPACES.Status AS TableSpace_Status
        INTO vTableSpace_Status
        FROM ALL_TABLES
        INNER JOIN USER_TABLESPACES
            ON ALL_TABLES.TableSpace_Name = USER_TABLESPACES.TableSpace_Name
        WHERE ALL_TABLES.Owner = 'RD'
        AND ALL_TABLES.Table_Name = 'EMAILLOG';
        
        --Only attempt the insert if the tablespace is online
        IF vTableSpace_Status = 'ONLINE' THEN
            
            INSERT
            INTO RD.EMAILLOG
            (
                DATETIMEX,
                FROM_,
                SUBJECT,
                TO_,
                BODY
            )
            VALUES
            (
                SYSDATE,
                Sender,
                Subject,
                Recipient,
                Msg
            );
            
            COMMIT;
            
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
        
        SELECT CASE
            --if there are multiple levels to the domain, get the last one only
            WHEN INSTR(SubDomains, '.') > 0 THEN SUBSTR
            (
                SubDomains,
                INSTR(SubDomains, '.', -1, 1) + 1
            )
            ELSE SubDomains
        END  || '.' || LOWER(RootZoneDatabase_ID)
        INTO vSenderDomain
        FROM TABLE
        (
            PARSEEMAILADDRESS(Sender)
        )
        WHERE RootZoneDatabase_ID IS NOT NULL
        AND LocalPart IS NOT NULL
        AND SubDomains IS NOT NULL;
        
        IF (vSenderDomain = 'haddenindustries.com') THEN
            
            UTL_SMTP.Auth
            (
                c => xConnection,
                username => 'maksym.shostak@haddenindustries.com',
                password => 'xjufbxwrfhrpzopn',
                schemes  => UTL_SMTP.All_Schemes
            );
            
        ELSIF (vSenderDomain = 'jym.fit') THEN
            
            UTL_SMTP.Auth
            (
                c => xConnection,
                username => 'info@jym.fit',
                password => 'rjjblkwbfitwqdgx',
                schemes  => UTL_SMTP.All_Schemes
            );
            
        ELSE
            
            RAISE NO_DATA_FOUND;
            
        END IF;
        
        UTL_SMTP.Mail(xConnection, sender);
        
        --TO
        FOR C IN
        (
            SELECT Text AS EmailAddress
            FROM TABLE
            (
                RD.SPLIT(Recipient, ';')
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
                RD.SPLIT(CC, ';')
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
                RD.SPLIT(BCC, ';')
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

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    RD.EMAIL.SEND
    (
        SENDER=>'maksym.shostak@haddenindustries.com',
        RECIPIENT=>'maksym@shostak.info',
        CC=>NULL,
        BCC=>NULL,
        SUBJECT=>'Test from Oracle',
        MSG=>'If this works, THEN you can send email via smtp.gmail.com!',
        ATTACHMENTS=>NULL
    );
    
END;
/

BEGIN
    
    RD.EMAIL.SEND
    (
        SENDER=>'info@jym.fit',
        RECIPIENT=>'maksym@shostak.info',
        CC=>NULL,
        BCC=>NULL,
        SUBJECT=>'Test from Oracle',
        MSG=>'If this works, THEN you can send email via smtp.gmail.com!',
        ATTACHMENTS=>NULL
    );
    
END;
/

BEGIN
    
    RD.EMAIL.SEND
    (
        SENDER=>'info@maliciousdomain.net',
        RECIPIENT=>'maksym@shostak.info',
        CC=>NULL,
        BCC=>NULL,
        SUBJECT=>'Test from Oracle',
        MSG=>'If this works, THEN you can send email via smtp.gmail.com!',
        ATTACHMENTS=>NULL
    );
    
END;
/
*/