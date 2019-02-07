SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_S_GBRCOMPANIESHOUSE(gOverwrite IN INTEGER DEFAULT 0)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'S_GBRCOMPANIESHOUSE';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := vTable_Name || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    vURL VARCHAR2(4000 BYTE) := '';
    vFileName VARCHAR2(4000 BYTE) := '';
    nParts PLS_INTEGER := 0;
    nPartCurrent PLS_INTEGER := 1;
    
    --Error variables
    vError VARCHAR2(255 BYTE) := '';
    HANDLED EXCEPTION;
    
BEGIN
    
    DBMS_OUTPUT.Enable(NULL);
    
    SELECT LOWER(USER || '@' || Global_Name)
    INTO vSender
    FROM GLOBAL_NAME;
    
    BEGIN
        
        vMsg := CHR(10)
        || '<html lang="en">' || CHR(10)
        || '<head>' || CHR(10)
        || '<title>' || TEXT_TO_HTML(vSubject) || '</title>' || CHR(10)
        || '<base target="_blank" />' || CHR(10) --make hyperlinks open in new tab instead of same window
        || '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />' || CHR(10)
        || '<meta name="format-detection" content="telephone=no" />' || CHR(10) --prevent recognition of numbers as telephone numbers
        || '</head>' || CHR(10)
        || '<body>' || CHR(10)
        || '<table border="1">' || CHR(10)
        || '<thead>' || CHR(10)
        || '<tr>'
        || '<th>' || TEXT_TO_HTML('Time') || '</th>'
        || '<th>' || TEXT_TO_HTML('Action') || '</th>'
        || '<th>' || TEXT_TO_HTML('Object name') || '</th>'
        || '<th>' || TEXT_TO_HTML('Detail') || '</th>'
        || '<th>' || TEXT_TO_HTML('Outcome') || '</th>'
        || '</tr>' || CHR(10)
        || '</thead>' || CHR(10)
        || '<tbody>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'Find' || '</td>'
        || '<td>' || 'nParts' || '</td>'
        || '<td>' || '' || '</td>';
            
        BEGIN
            
            vURL := FIND_URL_ON_WEB_PAGE
            (
                Get_Table_Refresh_Source_URL(vTable_Name),
                'BasicCompanyData'
            );
            
            SELECT TO_NUMBER
            (
                SUBSTR
                (
                    vURL,
                    --The last period
                    INSTR(vURL, '.', -1, 1) - 1,
                    1
                )
            )
            INTO nParts
            FROM DUAL;
            
            vMsg := vMsg || '<td>' || TO_CHAR(nParts) || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        END;
        
        
        WHILE (nPartCurrent <= nParts) LOOP
            
            
            IF (nPartCurrent > 1) THEN
                
                vURL := REPLACE(vURL, '-part' || TO_CHAR(nPartCurrent - 1) || '_', '-part' || TO_CHAR(nPartCurrent) || '_');
                
            END IF;
            
            
            nPartCurrent := nPartCurrent + 1;
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || TEXT_TO_HTML(vTable_Name) || '</td>'
            || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
            
            
            vFileName := SUBSTR(vURL, INSTR(vURL, '/', -1) + 1);
            
            
            BEGIN
                
                SELECT FileName
                INTO vFileName
                FROM DIR
                WHERE FileName = vFileName;
                
                IF (gOverwrite = 0) THEN
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML('File already exists') || '</td>'
                    || '</tr>';
                    
                    --Go to the next iteration
                    CONTINUE;
                    
                END IF;
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                
                NULL;
                
            END;
            
            
            BEGIN
                
                WGET(vURL);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END;
            
            --Remove any previous versions of this file
            FOR C IN
            (
                SELECT FileName
                FROM
                (
                    SELECT FileName,
                    ROW_NUMBER() OVER (ORDER BY FileName DESC) AS RN,
                    COUNT(*) OVER() AS Count_
                    FROM DIR
                    WHERE FileName LIKE '%BasicCompanyData%-part' || TO_CHAR(nPartCurrent - 1) || '%'
                )
                WHERE RN != 1
                AND Count_ > 1
            ) LOOP
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'REMOVE' || '</td>'
                || '<td>' || TEXT_TO_HTML(vTable_Name) || '</td>'
                || '<td>' || TEXT_TO_HTML(C.FileName) || '</td>';
                
                BEGIN
                    
                    UTL_FILE.FRemove('RD', C.FileName);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                    || '</tr>';
                    
                EXCEPTION
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                    || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
            END LOOP;            
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN (vTable_Name)
            ORDER BY Table_Name
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'UPDATE' || '</td>'
            || '<td>' || 'TABLELOOKUP' || '</td>'
            || '<td>' || C.Table_Name || '</td>';
            
            TOUCH(C.Table_Name);
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '</tbody>' || CHR(10)
        || '</table>' || CHR(10)
        || '</body>' || CHR(10)
        || '</html>';
        
        SELECT REPLACE
        (
            XMLSERIALIZE
            (
                DOCUMENT HTML_ADD_INLINE_STYLE
                (
                    XMLPARSE(DOCUMENT vMsg)
                ) AS CLOB INDENT SIZE = 2
            ),
            '&apos;',
            '&#39;'
        )
        INTO vMsg
        FROM DUAL;
        
        
    EXCEPTION
    WHEN HANDLED THEN
        
        vMsg := vMsg || CHR(10)
        || '</tbody>' || CHR(10)
        || '</table>' || CHR(10)
        || '</body>' || CHR(10)
        || '</html>';
        
        SELECT REPLACE
        (
            XMLSERIALIZE
            (
                DOCUMENT HTML_ADD_INLINE_STYLE
                (
                    XMLPARSE(DOCUMENT vMsg)
                ) AS CLOB INDENT SIZE = 2
            ),
            '&apos;',
            '&#39;'
        )
        INTO vMsg
        FROM DUAL;
        
    WHEN OTHERS THEN
        
        ROLLBACK;
        
        vError := SUBSTRB(SQLErrM, 1, 255);
        
        vMsg := vMsg || ' (' || vError || ')';
        
        DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(vMsg));
        
    END;
    
    
    BEGIN
        
        EMAIL.SEND
        (
            SENDER=>vSender,
            RECIPIENT=>vRecipient,
            CC=>vCC,
            BCC=>vBCC,
            SUBJECT=>vSubject,
            MSG=>vMsg,
            ATTACHMENTS=>NULL
        );
        
    EXCEPTION
    WHEN OTHERS THEN
        
        vError := SUBSTRB(SQLErrM, 1, 248);
        
        DBMS_OUTPUT.PUT_LINE('EMAIL: ' || vError);
        
    END;
    
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_S_GBRCOMPANIESHOUSE(gOverwrite=>0);
    
END;
/
*/