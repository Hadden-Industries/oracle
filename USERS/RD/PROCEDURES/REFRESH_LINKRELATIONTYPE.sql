SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_LINKRELATIONTYPE(nForceRefresh INTEGER DEFAULT 0)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'LINKRELATIONTYPE';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nDeletes SIMPLE_INTEGER := 0;
    bExists BOOLEAN := FALSE;
    nRowsInserted SIMPLE_INTEGER := 0;
    nRowsUpdated SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vURL VARCHAR2(4000 BYTE) := Get_Table_Refresh_Source_URL(vTable_Name);
    xXML XMLTYPE;
    
    --Document formatting variable
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    
    --Exception handling variable
    HANDLED EXCEPTION;
    vError VARCHAR2(255 BYTE) := '';
    
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
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL
            (
                gURL => vURL,
                gTableLookup_Name => vTable_Name
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        END;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('INBOUND')
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL);
        
        nDeletes := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF nDeletes > 0 AND nForceRefresh = 0 THEN --Nothing to update, so exit
            
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
            
            
            RAISE HANDLED;
            
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        SELECT XMLPARSE(DOCUMENT Data)
        INTO xXML
        FROM LATEST$INBOUND
        WHERE TableLookup_Name = vTable_Name;
        
        
        FOR C IN
        (
            SELECT Value AS Name,
            SINGLE_LINE(Description) AS Description,
            CASE Spec_XRef_Type
                WHEN 'uri' THEN Spec_XRef_Data
                ELSE 'http://www.iana.org/go/' || Spec_XRef_Data
            END AS URL,
            CAST(Updated AS TIMESTAMP) AS DateTimeUpdated,
            SINGLE_LINE
            (
                LTRIM(Spec, ',')
            ) AS URLComment,
            CAST(Date_ AS TIMESTAMP) AS DateTimeStart,
            SINGLE_LINE(Note) AS Comments
            FROM XMLTABLE
            (
                XMLNAMESPACES(DEFAULT 'http://www.iana.org/assignments'),
                '/registry/registry/record' PASSING xXML
                /*XMLTYPE
                (
                    BFileName('RD', 'link-relations.xml'),
                    NLS_CharSet_ID('AL32UTF8')
                )*/
                COLUMNS ID FOR ORDINALITY,
                Date_ DATE PATH '@date',
                Updated DATE PATH '@updated',
                Value VARCHAR2(100 BYTE) PATH 'value',
                Description VARCHAR2(4000 BYTE) PATH 'description',
                Spec_XRef_Type VARCHAR2(4000 BYTE) PATH 'spec/xref/@type',
                Spec_XRef_Data VARCHAR2(4000 BYTE) PATH 'spec/xref/@data',
                Spec VARCHAR2(4000 BYTE) PATH 'spec',
                Note VARCHAR2(4000 BYTE) PATH 'note'
            )
            --
            MINUS
            --
            SELECT Name,
            Description,
            URL,
            DateTimeUpdated,
            URLComment,
            DateTimeStart,
            Comments
            FROM LINKRELATIONTYPE
            ORDER BY 1
        ) LOOP
            
            
            bExists := FALSE;
            
            
            FOR D IN
            (
                SELECT Name,
                Description,
                URL,
                DateTimeUpdated,
                URLComment,
                DateTimeStart,
                Comments
                FROM LINKRELATIONTYPE
                WHERE Name = C.Name
            ) LOOP
                
                
                bExists := TRUE;
                
                
                IF C.Description != D.Description THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Description' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET Description = C.Description
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Description) || '=>' || TEXT_TO_HTML(C.Description) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.URL != D.URL THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.URL' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET URL = C.URL
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.URL) || '=>' || TEXT_TO_HTML(C.URL) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateTimeUpdated, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateTimeUpdated, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.DateTimeUpdated' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET DateTimeUpdated = C.DateTimeUpdated
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateTimeUpdated || '=>' || C.DateTimeUpdated || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.URLComment, CHR(0)) != COALESCE(D.URLComment, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.URLComment' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET URLComment = C.URLComment
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.URLComment) || '=>' || TEXT_TO_HTML(C.URLComment) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateTimeStart, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateTimeStart, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.DateTimeStart' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET DateTimeStart = C.DateTimeStart
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateTimeStart || '=>' || C.DateTimeStart || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Comments' || '</td>'
                    || '<td>' || C.Name || '</td>';
                    
                    UPDATE
                    LINKRELATIONTYPE
                    SET Comments = C.Comments
                    WHERE Name = C.Name;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Comments) || '=>' || TEXT_TO_HTML(C.Comments) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
            END LOOP;
            
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || vTable_Name || '</td>'
                || '<td>' || TEXT_TO_HTML(C.Name) || ','
                || TEXT_TO_HTML(C.Description) || ','
                || TEXT_TO_HTML(C.URL) || ','
                || TEXT_TO_HTML(C.DateTimeUpdated) || ','
                || TEXT_TO_HTML(C.URLComment) || ','
                || TEXT_TO_HTML(C.DateTimeStart) || ','
                || TEXT_TO_HTML(C.Comments) || '</td>';
                
                INSERT
                INTO LINKRELATIONTYPE
                (
                    NAME,
                    DESCRIPTION,
                    URL,
                    DATETIMEUPDATED,
                    URLCOMMENT,
                    DATETIMESTART,
                    COMMENTS
                )
                VALUES
                (
                    C.NAME,
                    C.DESCRIPTION,
                    C.URL,
                    C.DATETIMEUPDATED,
                    C.URLCOMMENT,
                    C.DATETIMESTART,
                    C.COMMENTS
                );
                
                nRowsInserted := nRowsInserted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
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
            || '<td>' || 'GATHER STATS' || '</td>'
            || '<td>' || C.Table_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_STATS.Gather_Table_Stats
            (
                ownname => NULL,
                tabname => C.Table_Name,
                method_opt => 'FOR ALL COLUMNS SIZE SKEWONLY',
                cascade => TRUE,
                estimate_percent => 100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
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
        
        
        IF nRowsUpdated > 0 OR nRowsInserted > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || vTable_Name || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table(vTable_Name, vGoogleOutput);
                
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
        
        DBMS_OUTPUT.Put_Line(DBMS_LOB.Substr(vMsg));
        
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
    
    REFRESH_LINKRELATIONTYPE(1);
    
END;
/
*/