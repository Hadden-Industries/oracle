CREATE OR REPLACE
PROCEDURE WGET
(
    gURL IN VARCHAR2,
    gDirectory IN VARCHAR2 DEFAULT USER,
    gFileName IN VARCHAR2 DEFAULT NULL,
    gMethod IN VARCHAR2 DEFAULT 'GET'
)
AUTHID CURRENT_USER
AS
    
    --Download variables
    bData BLOB;
    vProxy VARCHAR2(32767 BYTE) := '';
    vFileName VARCHAR2(32767 BYTE) := '';
    req UTL_HTTP.REQ;
    resp UTL_HTTP.RESP;
    rResp RAW(1000);
    p_WalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
    p_WalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
    --POST method parsing
    lQuery_String VARCHAR2(32767 BYTE) := '';
    lContent_Length INTEGER := 0;
    
    --Error handling variable
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => bData,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open(bData, DBMS_LOB.LOB_ReadWrite);
    
    
    IF gFileName IS NULL THEN
        
        vFileName := SUBSTR(gURL, INSTR(gURL, '/', -1) + 1);
        
    ELSE
        
        vFileName := gFileName;
        
    END IF;
    
    
    DBMS_APPLICATION_INFO.Set_Module(module_name=>'WGET', action_name=>'Retrieving proxy information');
    
    
    BEGIN
        
        SELECT 'http://' || IPV4 || ':' || Port
        INTO vProxy
        FROM PROXY
        WHERE IPV4 IS NOT NULL
        AND Port IS NOT NULL;
        
        DBMS_APPLICATION_INFO.Set_Action('Setting proxy');
        
        UTL_HTTP.SET_PROXY(vProxy, NULL);
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        NULL;
        
    END;
    
    
    IF gMethod = 'POST' THEN
        
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
    
    
    IF SUBSTRB(gURL, 1, 5) = 'https' THEN
        
        BEGIN
            
            DBMS_APPLICATION_INFO.Set_Action('Adding wallet');
            
            SELECT Path,
            Password
            INTO p_WalletPath,
            p_WalletPassword
            FROM ORACLEDATABASEWALLET
            WHERE Path IS NOT NULL
            AND Password IS NOT NULL;
            
            UTL_HTTP.Set_Wallet(p_WalletPath, p_WalletPassword);
            
            DBMS_APPLICATION_INFO.Set_Action('Added wallet');
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 200);
            
            DBMS_OUTPUT.Put_Line('Error opening certificate store: ' || vError);
            
            RAISE;
            
        END;
        
    END IF;
    
    req := UTL_HTTP.Begin_Request
    (
        url => gURL,
        method => gMethod
    );
    
    UTL_HTTP.Set_Header
    (
        r => req,
        name => 'Content-Type',
        value => 'application/x-www-form-urlencoded'
    );
    
    IF gMethod = 'POST' THEN
        
        UTL_HTTP.Set_Header
        (
            r => req,
            name => 'Content-Length',
            value => TO_CHAR(lContent_Length)
        );
        
        UTL_HTTP.Write_Text
        (
            r => req,
            data => lQuery_String
        );
        
    END IF;
    
    resp := UTL_HTTP.Get_Response(req);
    
    BEGIN
        
        DBMS_APPLICATION_INFO.Set_Action('Obtaining BLOB');
        
        LOOP
            
            UTL_HTTP.Read_Raw(resp, rResp, 1000);
            
            DBMS_LOB.WriteAppend(bData, UTL_RAW.Length(rResp), TO_BLOB(rResp));
            
        END LOOP;
        
        UTL_HTTP.End_Response(resp);
        
    EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
        
        UTL_HTTP.End_Response(resp);
        
    WHEN OTHERS THEN
        
        vError := SUBSTRB(SQLErrM, 1, 255);
        
        DBMS_OUTPUT.Put_Line(vError);
        
    END;
    
    
    DBMS_APPLICATION_INFO.Set_Action('Saving BLOB');
    
    BLOB_TO_FILE(bData, gDirectory, vFileName);
    
    DBMS_APPLICATION_INFO.Set_Module(module_name=>'', action_name=>'');
    
    IF DBMS_LOB.GetLength(bData) > 0 THEN
        
        DBMS_LOB.FreeTemporary(bData);
        
    END IF;
    
END;
/


/*
--test
SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    --WGET('http://unicode.org/iso15924/iso15924.txt.zip');
    --WGET('http://download.geonames.org/export/dump/YT.zip');
    --WGET('http://download.geonames.org/export/dump/alternateNames.zip');
    --WGET('http://download.geonames.org/export/dump/allCountries.zip');
    --WGET(gURL=>'http://download.geonames.org/export/dump/countryInfo.txt', gFileName=>'S_COUNTRYINFO.txt');
    
END;
/
*/