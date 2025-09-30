SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GBRONSRGC(gDownload IN INTEGER DEFAULT 1)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'GBRONSRGC ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    nRowsAffected SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vURLIndex VARCHAR2(75 BYTE) := 'https://geoportal.statistics.gov.uk/geoportal/catalog/content/filelist.page';
    vURLRGC VARCHAR2(4000 BYTE) := '';
    
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
        
        
        IF gDownload = 1 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'FIND_URL_ON_WEB_PAGE' || '</td>'
            || '<td>' || 'Register_of_Geographic_Codes' || '</td>'
            || '<td>' || '' || '</td>';
            
            BEGIN
                
                vURLRGC := FIND_URL_ON_WEB_PAGE(vURLIndex, 'Register_of_Geographic_Codes');
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END;
            
            
            IF vURLRGC IS NOT NULL THEN
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            ELSE
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END IF;
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(vURLRGC) || '</td>';
            
            BEGIN
                
                SAVE_DATA_FROM_URL
                (
                    gURL=>vURLRGC,
                    gFileName=>'S_GBRONSRGC.xlsx'
                );
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'COMMIT' || '</td>'
            || '<td>' || USER || '</td>'
            || '<td>' || '' || '</td>';
            
            COMMIT;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM
                (
                    SELECT Table_Name
                    FROM USER_TABLES
                    --
                    UNION ALL
                    --
                    SELECT View_Name
                    FROM ALL_VIEWS
                )
                WHERE Table_Name IN
                (
                    'INBOUND',
                    'S_GBRONSRGC'
                )
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
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GBRONSRGC' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO GBRONSRGC X
        USING
        (
            SELECT ID,
            CASE
                WHEN REGEXP_LIKE(First_CHD_ID, '^([A-Z]{1}[[:digit:]]{8})$') THEN First_CHD_ID
                ELSE NULL
            END AS First$CHD_ID,
            CASE
                WHEN REGEXP_LIKE(Last_CHD_ID, '^([A-Z]{1}[[:digit:]]{8})$') THEN Last_CHD_ID
                ELSE NULL
            END AS Last$CHD_ID,
            CASE
                WHEN REGEXP_LIKE(Reserved_CHD_ID, '^([A-Z]{1}[[:digit:]]{8})$') THEN Reserved_CHD_ID
                ELSE NULL
            END AS Reserved$CHD_ID,
            Abbreviation,
            DateAdded,
            DateStart,
            Owner,
            Name,
            NumberArchived,
            NumberCrossBorder,
            Status,
            Theme,
            DateUpdated,
            NumberLive
            FROM S_GBRONSRGC
            WHERE REGEXP_LIKE(ID, '^([A-Z]{1}[[:digit:]]{2})$')
            --Ignore the 'reserved' identifiers
            AND Reserved_CHD_ID IS NOT NULL
            AND DateAdded IS NOT NULL
            --
            MINUS
            --
            SELECT ID,
            First$CHD_ID,
            Last$CHD_ID,
            Reserved$CHD_ID,
            Abbreviation,
            DateAdded,
            DateStart,
            Owner,
            Name,
            NumberArchived,
            NumberCrossBorder,
            Status,
            Theme,
            DateUpdated,
            NumberLive
            FROM GBRONSRGC
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.First$CHD_ID = Y.First$CHD_ID,
        X.Last$CHD_ID = Y.Last$CHD_ID,
        X.Reserved$CHD_ID = Y.Reserved$CHD_ID,
        X.Abbreviation = Y.Abbreviation,
        X.DateAdded = Y.DateAdded,
        X.DateStart = Y.DateStart,
        X.Owner = Y.Owner,
        X.Name = Y.Name,
        X.NumberArchived = Y.NumberArchived,
        X.NumberCrossBorder = Y.NumberCrossBorder,
        X.Status = Y.Status,
        X.Theme = Y.Theme,
        X.DateUpdated = Y.DateUpdated,
        X.NumberLive = Y.NumberLive
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            FIRST$CHD_ID,
            LAST$CHD_ID,
            RESERVED$CHD_ID,
            ABBREVIATION,
            DATEADDED,
            DATESTART,
            OWNER,
            NAME,
            NUMBERARCHIVED,
            NUMBERCROSSBORDER,
            STATUS,
            THEME,
            DATEUPDATED,
            NUMBERLIVE
        )
        VALUES
        (
            Y.ID,
            Y.First$CHD_ID,
            Y.Last$CHD_ID,
            Y.Reserved$CHD_ID,
            Y.Abbreviation,
            Y.DateAdded,
            Y.DateStart,
            Y.Owner,
            Y.Name,
            Y.NumberArchived,
            Y.NumberCrossBorder,
            Y.Status,
            Y.Theme,
            Y.DateUpdated,
            Y.NumberLive
        );
        
        nRowsAffected := nRowsAffected + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('GBRONSRGC')
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('GBRONSRGC')
            ORDER BY Table_Name
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'GATHER STATS' || '</td>'
            || '<td>' || C.Table_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_STATS.Gather_Table_Stats
            (
                OWNNAME=>NULL,
                TABNAME=>C.Table_Name,
                METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE=>TRUE,
                ESTIMATE_PERCENT=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nRowsAffected > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'GBRONSRGC' || '</td>';
            
            BEGIN
                
                --GOOGLE.Import_Table('GBRONSRGC', vGoogleOutput);
                NULL;
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(COALESCE(vGoogleOutput, vError)) || '</td>'
            || '</tr>';
            
        END IF;
        
        
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
        
        DBMS_OUTPUT.Put_Line
        (
            DBMS_LOB.Substr(vMsg)
        );
        
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
        
        DBMS_OUTPUT.Put_Line('EMAIL: ' || vError);
        
    END;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_GBRONSRGC(0);
    
END;
/
*/