CREATE OR REPLACE
FUNCTION URL_TO_BLOB
(
    gURL IN VARCHAR2,
    gMethod IN VARCHAR2 DEFAULT 'GET'
)
RETURN BLOB
AS
    
    --Program variables
    bData BLOB := EMPTY_BLOB();
    vProxy VARCHAR2(32767 BYTE) := '';
    nRetry PLS_INTEGER := 0;
    nRetryMax PLS_INTEGER := 10;
    nRetrySeconds PLS_INTEGER := 10;
    req UTL_HTTP.REQ;
    resp UTL_HTTP.RESP;
    rResp RAW(1000);
    p_WalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
    p_WalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
    --POST method parsing
    lQuery_String VARCHAR2(32767 BYTE) := '';
    lContent_Length INTEGER := 0;
    
    --Error variable
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_APPLICATION_INFO.Set_Action('Initialising LOBs');
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => bData,
        cache => TRUE,
        dur => DBMS_LOB.SESSION
    );
    
    DBMS_LOB.Open
    (
        bData,
        DBMS_LOB.LOB_ReadWrite
    );
    
    
    IF gMethod = 'POST' THEN
        
        DBMS_APPLICATION_INFO.Set_Action('Parsing URL');
        
        SELECT Query_String,
        LENGTHB(Query_String) AS Content_Length
        INTO lQuery_String,
        lContent_Length
        FROM
        (
            SELECT SUBSTR(URL, INSTR(URL, '?', -1) + 1) AS Query_String
            FROM
            (
                SELECT gURL AS URL
                FROM DUAL
            )
        );
        
    END IF;
    
    
    DBMS_APPLICATION_INFO.Set_Action('Obtaining proxy information');
    
    BEGIN
        
        SELECT 'http://' || IPV4 || ':' || Port
        INTO vProxy
        FROM PROXY
        WHERE IPV4 IS NOT NULL
        AND Port IS NOT NULL;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        vProxy := NULL;
        
    END;
    
    
    DBMS_APPLICATION_INFO.Set_Action('Setting proxy');
    
    UTL_HTTP.SET_PROXY(vProxy, NULL);
    
    
    IF SUBSTRB(gURL, 1, 5) = 'https' THEN
        
        BEGIN
            
            DBMS_APPLICATION_INFO.Set_Action('Opening certificate wallet');
            
            SELECT Path,
            Password
            INTO p_WalletPath,
            p_WalletPassword
            FROM ORACLEDATABASEWALLET
            WHERE Path IS NOT NULL
            AND Password IS NOT NULL;
            
            UTL_HTTP.Set_Wallet(p_WalletPath, p_WalletPassword);
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 200);
            
            DBMS_OUTPUT.Put_Line('Error opening certificate store: ' || vError);
            
            RAISE NO_DATA_FOUND;
            
        END;
        
    END IF;
    
    
    WHILE nRetry < nRetryMax LOOP
        
        BEGIN
            
            DBMS_APPLICATION_INFO.Set_Action('Beginning request');
            
            req := UTL_HTTP.Begin_Request
            (
                url => gURL,
                method => gMethod,
                --https://asktom.oracle.com/pls/asktom/f?p=100:11:::NO:RP:P11_QUESTION_ID:9536564700346663150
                https_host => CASE WHEN SUBSTRB(gURL, 1, 23) = 'https://api.darksky.net' THEN 'darksky.net'
                    WHEN SUBSTRB(gURL, 1, 24) = 'https://iso639-3.sil.org' THEN 'ssl746180.cloudflaressl.com'
                    ELSE NULL
                END
            );
            
            DBMS_APPLICATION_INFO.Set_Action('Setting header');
            
            UTL_HTTP.Set_Header
            (
                r => req,
                name => 'Content-Type',
                value => 'application/x-www-form-urlencoded'
            );
            
            IF gMethod = 'POST' THEN
                
                DBMS_APPLICATION_INFO.Set_Action('Setting POST header');
                
                UTL_HTTP.Set_Header
                (
                    r => req,
                    name => 'Content-Length',
                    value => TO_CHAR(lContent_Length)
                );
                
                DBMS_APPLICATION_INFO.Set_Action('Writing POST text');
                
                UTL_HTTP.Write_Text
                (
                    r => req,
                    data => lQuery_String
                );
                
            END IF;
            
            DBMS_APPLICATION_INFO.Set_Action('Getting response');
            
            resp := UTL_HTTP.Get_Response(req);
            
            BEGIN
                
                DBMS_APPLICATION_INFO.Set_Action('Obtaining BLOB');
                
                LOOP
                    
                    UTL_HTTP.Read_Raw(resp, rResp, 1000);
                    
                    DBMS_LOB.WriteAppend(bData, UTL_RAW.Length(rResp), TO_BLOB(rResp));
                    
                END LOOP;
                
                DBMS_APPLICATION_INFO.Set_Action('Ending response');
                
                UTL_HTTP.End_Response(resp);
                
            EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
                
                DBMS_APPLICATION_INFO.Set_Action('Ending response');
                
                UTL_HTTP.End_Response(resp);
                
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                DBMS_OUTPUT.Put_Line(vError);
                
            END;            
            
            --Leave the loop when you first finish successfully
            EXIT;
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            DBMS_OUTPUT.Put_Line(vError);
            
            nRetry := nRetry + 1;
            
            DBMS_APPLICATION_INFO.Set_Action('Sleeping');
            
            DBMS_LOCK.Sleep(nRetrySeconds);
            
        END;
            
    END LOOP;
    
    
    IF nRetry = nRetryMax THEN
        
        RAISE NO_DATA_FOUND;
        
    END IF;
    
    
    DBMS_APPLICATION_INFO.Set_Action(NULL);
    
    RETURN bData;
    
END;
/

/*
--test
SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT URL_TO_BLOB
(
    gURL=>'https://iso639-3.sil.org/sites/iso639-3/files/downloads/iso-639-3_Retirements.tab'
)
FROM DUAL;

--test https_host
SELECT URL_TO_BLOB
(
    gURL=>'https://api.darksky.net/forecast/4c3acbbca35922c1ef4bd19115adfd79/51.594,-0.113,2018-07-09T21:32:30Z?units=si'
)
FROM DUAL;
*/