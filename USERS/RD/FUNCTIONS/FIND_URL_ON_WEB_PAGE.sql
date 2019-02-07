SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
FUNCTION FIND_URL_ON_WEB_PAGE
(
    gURL IN VARCHAR2,
    gText IN VARCHAR2 DEFAULT NULL,
    gMethod VARCHAR2 DEFAULT 'GET'
)
RETURN VARCHAR2
AS
    
    --Program variables
    cWebPage CLOB := EMPTY_CLOB();
    nA PLS_INTEGER := 0;
    vFragment VARCHAR2(4000 BYTE) := '';
    
    --UTL_HTTP variables
    vProxy VARCHAR2(32767 BYTE) := '';
    req UTL_HTTP.REQ;
    resp UTL_HTTP.RESP;
    vResp VARCHAR2(1000 CHAR) := '';
    p_WalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
    p_WalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
    --POST method parsing
    lQuery_String VARCHAR2(32767 BYTE) := '';
    lContent_Length INTEGER := 0;
    
    --Error handling variable
    HANDLED EXCEPTION;
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.Enable;
    
    --Attempt the call twice - doesn't seem to work with one call for secure HTTP
    FOR i IN 0..1 LOOP
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => cWebPage,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open(cWebPage, DBMS_LOB.LOB_ReadWrite);
    
    
    BEGIN
        
        SELECT 'http://' || IPV4 || ':' || Port
        INTO vProxy
        FROM PROXY
        WHERE IPV4 IS NOT NULL
        AND Port IS NOT NULL;
        
        UTL_HTTP.Set_Proxy(vProxy, NULL);
        
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
            
            RAISE HANDLED;
            
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
        
        LOOP
            
            UTL_HTTP.Read_Text(resp, vResp, 1000);
            
            DBMS_LOB.WriteAppend(cWebPage, LENGTH(vResp), vResp);
            
        END LOOP;
        
        UTL_HTTP.End_Response(resp);
        
    EXCEPTION
    WHEN UTL_HTTP.END_OF_BODY THEN
        
        UTL_HTTP.End_Response(resp);
        
    END;
    
    nA := REGEXP_COUNT(cWebPage, '<a ');
    
    FOR i IN 1..nA LOOP
        
        FOR C IN
        (
            SELECT Offset,
            Position_End - Offset + LENGTH('</a>') AS Amount
            FROM
            (
                SELECT DBMS_LOB.Instr(cWebPage, '<a ', 1, i) AS Offset,
                --Some brain-dead sites forget to close with a '>', so ignore it
                DBMS_LOB.Instr(cWebPage, '</a', 1, i) AS Position_End
                FROM DUAL
            )
        ) LOOP
            
            vFragment := DBMS_LOB.Substr(cWebPage, C.Amount, C.Offset);
            
            IF INSTR(vFragment, ' href') > 0 THEN
                
                IF (gText IS NULL OR INSTR(vFragment, gText) > 0) THEN
                    
                    SELECT href
                    INTO vFragment
                    FROM XMLTABLE
                    (
                        '/a' PASSING XMLPARSE(DOCUMENT REPLACE(vFragment, '&', '&amp;') WELLFORMED)
                        COLUMNS href VARCHAR2(4000 BYTE) PATH '@href'
                    );
                    --If the URL begins with a / then it is relative to the head/base element else to the domain
                    --to do: Add head/base element find to resolve links where the base is specified
                    IF (SUBSTRB(vFragment, 1, 1) = '/' OR INSTR(vFragment, '/') = 0) THEN
                        
                        IF INSTR(gURL , '/', 1, 3) > 0 THEN
                            
                            vFragment := SUBSTR(gURL , 1, (INSTR(gURL , '/', 1, 3)-1))
                            || CASE
                                WHEN INSTR(vFragment, '/') = 0 THEN '/'
                                ELSE NULL
                            END
                            || vFragment;
                            
                        ELSE
                            
                            vFragment := gURL;
                            
                        END IF;
                        
                    END IF;
                    
                    DBMS_LOB.Close(cWebPage);
                    
                    IF DBMS_LOB.GetLength(cWebPage) > 0 THEN
                        
                        DBMS_LOB.FreeTemporary(cWebPage);
                        
                    END IF;
                    
                    RETURN UTL_URL.Escape(vFragment);
                    
                END IF;
                
            END IF;
        
        END LOOP;
    
    END LOOP;
    
    --If you have checked the whole page and found nothing, return NULL
    DBMS_LOB.Close(cWebPage);
    
    IF DBMS_LOB.GetLength(cWebPage) > 0 THEN
        
        DBMS_LOB.FreeTemporary(cWebPage);
        
    END IF;
    
    END LOOP;
    
    RETURN NULL;
    
EXCEPTION
WHEN HANDLED THEN
    
    RETURN NULL;
    
WHEN OTHERS THEN
    
    DBMS_OUTPUT.Put_Line
    (
        COALESCE
        (
            UTL_HTTP.Get_Detailed_SQLErrm, SUBSTRB(SQLErrM, 1, 255)
        )
    );
    
    RETURN NULL;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT FIND_URL_ON_WEB_PAGE('https://geoportal.statistics.gov.uk/geoportal/catalog/content/filelist.page', 'Code_History_Database_(')
FROM DUAL;

SELECT FIND_URL_ON_WEB_PAGE('http://www.bankofengland.co.uk')
FROM DUAL;

SELECT FIND_URL_ON_WEB_PAGE('http://download.companieshouse.gov.uk/en_output.html', 'BasicCompanyData')
FROM DUAL;
*/