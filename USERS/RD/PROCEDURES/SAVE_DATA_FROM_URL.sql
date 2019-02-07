CREATE OR REPLACE
PROCEDURE SAVE_DATA_FROM_URL
(
    gURL IN VARCHAR2,
    gTableLookup_Name IN VARCHAR2 DEFAULT NULL,
    gMethod IN VARCHAR2 DEFAULT 'GET',
    gUnzip IN NUMBER DEFAULT 0,
    gDirectory IN VARCHAR2 DEFAULT USER,
    gFileName IN VARCHAR2 DEFAULT NULL,
    gCharacterSet IN VARCHAR2 DEFAULT NULL
) AS
    
    --Program variables
    bData BLOB := EMPTY_BLOB();
    cData CLOB := EMPTY_CLOB();
    vProxy VARCHAR2(32767 BYTE) := '';
    nRetry PLS_INTEGER := 0;
    nRetryMax PLS_INTEGER := 10;
    nRetrySeconds PLS_INTEGER := 10;
    req UTL_HTTP.REQ;
    resp UTL_HTTP.RESP;
    rResp RAW(1000);
    p_WalletPath ORACLEDATABASEWALLET.Path%TYPE := '';
    p_WalletPassword ORACLEDATABASEWALLET.Password%TYPE := '';
    
    --Zip file variables
    lUnzip PLS_INTEGER := CASE
        WHEN LOWER(SUBSTRB(gURL, -3)) = 'zip' THEN 1
        ELSE gUnzip
    END;
    lListOfZipFiles ZIP.FILE_LIST;
    nZipFileIndex PLS_INTEGER := 0;
    
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
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open
    (
        bData,
        DBMS_LOB.LOB_ReadWrite
    );
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => cData,
        cache => TRUE,
        dur => DBMS_LOB.CALL
    );
    
    DBMS_LOB.Open
    (
        cData,
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
        
        NULL;
        
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
    
    
    IF lUnzip = 1 THEN
        
        DBMS_APPLICATION_INFO.Set_Action('Getting zip file list');
        
        lListOfZIPFiles := ZIP.Get_File_List(bData);
        
        FOR i IN lListOfZIPFiles.First .. lListOfZIPFiles.Last LOOP
            
            DBMS_APPLICATION_INFO.Set_Action('Finding file');
            
            IF (lListOfZIPFiles(i) NOT LIKE '\_\_%' ESCAPE '\' 
                    --World Bank API
                    AND lListOfZIPFiles(i) NOT LIKE '[Content\_Types]%' ESCAPE '\') THEN
                --DBMS_OUTPUT.Put_Line(TO_CHAR(i) || ': ' || lListOfZIPFiles(i));
                IF
                (
                    (
                        gFileName = 'S_CHD.csv'
                        AND lListOfZIPFiles(i) != 'ChangeHistory.csv'
                    )
                    OR
                    (
                        gFileName = 'S_GBRONSRGC.xlsx'
                        AND lListOfZIPFiles(i) NOT LIKE 'RGC\_%.xlsx' ESCAPE '\'
                    )
                ) THEN
                    
                    NULL;
                    
                ELSE
                    
                    nZipFileIndex := i;
                    
                    --Exit the loop as soon as you've found the first match
                    EXIT;
                    
                END IF;
                
            END IF;
            
        END LOOP;
        
    END IF;
    
    
    IF gTableLookup_Name IS NOT NULL THEN
        
        DBMS_APPLICATION_INFO.Set_Action('Converting to CLOB');
        
        DBMS_LOB.Append
        (
            cData,
            CASE
                WHEN lUnzip = 0 THEN BLOB_TO_CLOB(bData, gCharacterSet)
                ELSE BLOB_TO_CLOB
                (
                    ZIP.Get_File
                    (
                        bData,
                        lListOfZIPFiles(nZipFileIndex)
                    ),
                    gCharacterSet
                )
            END
        );
        
        DBMS_APPLICATION_INFO.Set_Action('Inserting into INBOUND');
        
        INSERT
        INTO INBOUND
        (
            URL,
            DATETIMEX,
            TABLELOOKUP_NAME,
            DATA--,
            --COMMENTS
        )
        VALUES
        (
            gURL,
            SYSDATE,
            gTableLookup_Name,
            cData
        );
        
        
    END IF;
    
    
    IF (gDirectory IS NOT NULL AND gFileName IS NOT NULL) THEN
        
        DBMS_APPLICATION_INFO.Set_Action('Saving BLOB');
        
        BLOB_TO_FILE
        (
            CASE
                WHEN lUnzip = 0 THEN bData
                ELSE ZIP.Get_File
                (
                    bData,
                    lListOfZIPFiles(nZipFileIndex)
                )
            END,
            gDirectory,
            gFileName
        );
        
    END IF;
    
    
    --Watch out for ORA-22289: cannot perform operation on an unopened file or LOB
    DBMS_APPLICATION_INFO.Set_Action('Freeing LOBs');
    
    DBMS_LOB.Close(cData);
    DBMS_LOB.FreeTemporary(cData);
    
    
    DBMS_LOB.Close(bData);
    DBMS_LOB.FreeTemporary(bData);
    
    
    DBMS_APPLICATION_INFO.Set_Action(NULL);
    
    
END;
/

/*
--test
SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN

--SAVE_DATA_FROM_URL('http://download.geonames.org/export/dump/deletes-2019-02-06.txt', 'GEONAMES');
--SAVE_DATA_FROM_URL('http://www.geolang.com/iso639-6/sortAlpha4.asp?selectA4letter=a&viewAlpha4=View', 'S_ISO639_6', 'POST');
--SAVE_DATA_FROM_URL('https://www.currency-iso.org/dam/downloads/lists/list_one.xml', 'CURRENCY');
--SAVE_DATA_FROM_URL('http://unicode.org/iso15924/iso15924.txt.zip', 'LANGUAGESCRIPT');
/*SAVE_DATA_FROM_URL
(
    gURL=>'http://download.companieshouse.gov.uk/BasicCompanyDataAsOneFile-2019-02-01.zip',
    gFileName=>'BasicCompanyDataAsOneFile-2019-02-01.csv'
);*/
--Save to two places at once
SAVE_DATA_FROM_URL
(
    gURL=>'http://unicode.org/iso15924/iso15924.txt.zip',
    gTableLookup_Name=>'S_ISO15924',
    gFileName=>'iso15924-utf8-20180827.txt'
);
/*SAVE_DATA_FROM_URL
(
    gURL=>'http://download.geonames.org/export/dump/countryInfo.txt',
    gTableLookup_Name=>'S_COUNTRYINFO',
    gMethod=>'GET',
    gUnzip=>0,
    gDirectory=>USER,
    gFileName=>'S_COUNTRYINFO2.txt'
);*/

END;
/
*/