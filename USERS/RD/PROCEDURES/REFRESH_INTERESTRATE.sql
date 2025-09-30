SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_INTERESTRATE(gDownload INTEGER DEFAULT 1)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'INTERESTRATE';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nRowsDeleted PLS_INTEGER := 0;
    nRowsInserted PLS_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
    --Exception handling variables
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
        
        IF (gDownload = 1) THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'WGET' || '</td>'
            || '<td>' || '' || '</td>'
            || '<td>' || 'INTERESTRATE.xml' || '</td>';
            
            BEGIN
                
                WGET
                (
                    gURL => Get_Table_Refresh_Source_URL(vTable_Name),
                    gFileName => 'INTERESTRATE.xml'
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
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM INTERESTRATE
        WHERE (Country_ID, DateStart) IN
        (
            SELECT 'GBR' AS Country_ID,
            DateStart
            FROM
            (
                SELECT Rate,
                TRUNC(DateStart) AS DateStart,
                TRUNC(DateEnd) AS DateEnd
                FROM INTERESTRATE
                WHERE Country_ID = 'GBR'
                --
                MINUS
                --
                SELECT Rate,
                MIN(DateX) AS DateStart,
                CASE
                    WHEN Batch_Number = Max$Batch_Number THEN NULL
                    ELSE CASE
                        --Fix gaps
                        WHEN LEAD(MIN(DateX), 1) OVER (ORDER BY Batch_Number) > MAX(DateX) + 1 THEN LEAD(MIN(DateX), 1) OVER (ORDER BY Batch_Number)
                        ELSE MAX(DateX) + 1
                    END
                END AS DateEnd
                FROM
                (
                    SELECT DateX,
                    Rate,
                    SUM(Rate_Step) OVER (ORDER BY DateX ROWS UNBOUNDED PRECEDING) AS Batch_Number,
                    SUM(Rate_Step) OVER () AS Max$Batch_Number
                    FROM
                    (
                        SELECT TRUNC(DateTimeX) AS DateX,
                        Rate,
                        CASE LAG(Rate) OVER (ORDER BY DateTimeX)
                            WHEN Rate THEN 0
                            ELSE 1
                        END AS Rate_Step
                        FROM XMLTABLE
                        (
                            XMLNAMESPACES
                            (
                                'http://www.gesmes.org/xml/2002-08-01'as "gesmes",
                                'http://www.bankofengland.co.uk/boeapps/iadb/agg_series' as "a"
                            ),
                            '/gesmes:Envelope/a:Cube/a:Cube' PASSING XMLTYPE
                            (
                                BFileName('RD', 'INTERESTRATE.xml'),
                                NLS_CHARSET_ID('AL32UTF8')
                            )
                            RETURNING SEQUENCE BY REF
                            COLUMNS DateTimeX DATE PATH '@TIME',
                            Rate NUMBER PATH '@OBS_VALUE'
                        )
                        WHERE DateTimeX IS NOT NULL
                    )
                )
                GROUP BY Rate,
                Batch_Number,
                Max$Batch_Number
            )
        );
        
        nRowsDeleted := nRowsDeleted + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT
        INTO INTERESTRATE
        (
            COUNTRY_ID,
            RATE,
            DATESTART,
            DATEEND
        )
        --
        SELECT 'GBR' AS Country_ID,
        Rate,
        MIN(DateX) AS DateStart,
        CASE
            WHEN Batch_Number = Max$Batch_Number THEN NULL
            ELSE CASE
                --Fix gaps
                WHEN LEAD(MIN(DateX), 1) OVER (ORDER BY Batch_Number) > MAX(DateX) + 1 THEN LEAD(MIN(DateX), 1) OVER (ORDER BY Batch_Number)
                ELSE MAX(DateX) + 1
            END
        END AS DateEnd
        FROM
        (
            SELECT DateX,
            Rate,
            SUM(Rate_Step) OVER (ORDER BY DateX ROWS UNBOUNDED PRECEDING) AS Batch_Number,
            SUM(Rate_Step) OVER () AS Max$Batch_Number
            FROM
            (
                SELECT TRUNC(DateTimeX) AS DateX,
                Rate,
                CASE LAG(Rate) OVER (ORDER BY DateTimeX)
                    WHEN Rate THEN 0
                    ELSE 1
                END AS Rate_Step
                FROM XMLTABLE
                (
                    XMLNAMESPACES
                    (
                        'http://www.gesmes.org/xml/2002-08-01'as "gesmes",
                        'http://www.bankofengland.co.uk/boeapps/iadb/agg_series' as "a"
                    ),
                    '/gesmes:Envelope/a:Cube/a:Cube' PASSING XMLTYPE
                    (
                        BFileName('RD', 'INTERESTRATE.xml'),
                        NLS_CHARSET_ID('AL32UTF8')
                    )
                    RETURNING SEQUENCE BY REF
                    COLUMNS DateTimeX DATE PATH '@TIME',
                    Rate NUMBER PATH '@OBS_VALUE'
                )
                WHERE DateTimeX IS NOT NULL
            )
        )
        GROUP BY Rate,
        Batch_Number,
        Max$Batch_Number
        --
        MINUS
        --
        SELECT Country_ID,
        Rate,
        TRUNC(DateStart),
        TRUNC(DateEnd)
        FROM INTERESTRATE
        WHERE Country_ID = 'GBR';
        
        nRowsInserted := nRowsInserted + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
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
        
        --Only gather stats, send update to Google if there has been a real update
        IF (nRowsDeleted + nRowsInserted > 0) THEN
            
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
                    OWNNAME => '',
                    TABNAME => C.Table_Name,
                    METHOD_OPT => 'FOR ALL COLUMNS SIZE SKEWONLY',
                    CASCADE => TRUE,
                    ESTIMATE_PERCENT => 100
                );
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            END LOOP;
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || vTable_Name || '</td>';
            
            BEGIN
                
                --GOOGLE.Import_Table(vTable_Name, vGoogleOutput);
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
        
        vError := SUBSTRB(SQLErrM, 1, 500);
        
        vMsg := vMsg || ' (' || vError || ')';
        
        DBMS_OUTPUT.Put_Line
        (
            DBMS_LOB.SUBSTR(vMsg)
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
        
        ROLLBACK;
        
        vError := SUBSTRB(SQLErrM, 1, 248);
        
        DBMS_OUTPUT.Put_Line('EMAIL: ' || vError);
        
    END;
    
END;
/

/*
--Check if rate changes have ever happened on a weekend
SELECT DateStart,
TO_CHAR(DateStart, 'Day')
FROM INTERESTRATE
WHERE TO_CHAR(DateStart, 'Day') IN
(
    'Saturday',
    'Sunday'
);

--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_INTERESTRATE;
    
END;
/
*/