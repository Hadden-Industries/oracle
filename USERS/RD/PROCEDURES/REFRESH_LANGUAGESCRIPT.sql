SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_LANGUAGESCRIPT(gDownload IN NUMBER DEFAULT 1)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'LANGUAGESCRIPT ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Download variables
    vURL VARCHAR2(32767 BYTE) := 'http://unicode.org/iso15924/iso15924.txt.zip';
    
    --Document formatting variable
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    
    --Program variables
    cCLOB CLOB := EMPTY_CLOB();
    nDeletes PLS_INTEGER := 0;
    nRows PLS_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    
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
        
        
        IF gDownload = 1 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
            
            SAVE_DATA_FROM_URL(vURL, 'LANGUAGESCRIPT');
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
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
            
            
            IF nDeletes > 0 THEN --Nothing to update, so exit
                
                FOR C IN
                (
                    SELECT Table_Name
                    FROM USER_TABLES
                    WHERE Table_Name IN
                    (
                        'LANGUAGESCRIPT',
                        'S_ISO15924'
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
                
                
                RAISE HANDLED;
                
                
            END IF;
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'S_ISO15924' || '</td>'
            || '<td>' || '' || '</td>';
            
            WGET(vURL);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('S_ISO15924')
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
                WHERE Table_Name IN ('S_ISO15924')
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
                    OWNNAME=>'',
                    TABNAME=>C.Table_Name,
                    METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                    CASCADE=>TRUE,
                    ESTIMATE_PERCENT=>100
                );
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            END LOOP;
            
        --Ending of if program argument set to download
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'LANGUAGESCRIPT' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO LANGUAGESCRIPT X
        USING
        (
            WITH LOWERALPHABET AS
            (
                SELECT ASCII,
                CHR(ASCII) AS Chr
                FROM
                (
                    SELECT (ASCIIFrom + LEVEL - 1) AS ASCII
                    FROM
                    (
                        SELECT 97 AS ASCIIFrom,
                        122 AS ASCIITo
                        FROM DUAL
                    )
                    CONNECT BY LEVEL <= (ASCIITo - ASCIIFrom + 1)
                )
            ),
            --
            S_S_ISO15924 AS --Raises too many errors exception otherwise (bug)
            (
                SELECT /*+ MATERIALIZE */
                ID,
                NumericCode,
                Name,
                NameFrench,
                PropertyValueAlias,
                DateModified
                FROM S_ISO15924
            )
            --
            SELECT ID,
            NumericCode,
            Name,
            NameFrench,
            PropertyValueAlias,
            DateModified
            FROM
            (
                SELECT ID,
                CASE
                    --Numeric code incorrect in downloaded file; http://www.unicode.org/iso15924/codechanges.html
                    WHEN ID = 'Modi' THEN '324'
                    ELSE NumericCode
                END AS NumericCode,
                TRIM(Name) AS Name,
                NameFrench,
                PropertyValueAlias,
                DateModified
                FROM S_S_ISO15924
                --
                UNION ALL
                --
                SELECT SUBSTR(ID, 1, 3) || B.Chr AS ID,
                RPAD(TO_CHAR(TO_NUMBER(A.NumericCode) + ROW_NUMBER() OVER (ORDER BY B.ASCII)), 3, '0') AS NumericCode,
                TRIM(SUBSTR(A.Name, 1, INSTR(A.Name, ' (') - 1)) AS Name,
                TRIM(SUBSTR(A.NameFrench, 1, INSTR(A.NameFrench, ' (') - 1)) AS NameFrench,
                A.PropertyValueAlias,
                A.DateModified
                FROM S_S_ISO15924 A
                CROSS JOIN LOWERALPHABET B
                WHERE Name = 'Reserved for private use (start)'
                AND SUBSTR(A.ID, -1) < B.Chr
                --
                UNION ALL
                --
                SELECT SUBSTR(ID, 1, 3) || B.Chr AS ID,
                RPAD(TO_CHAR(TO_NUMBER(A.NumericCode) - ROW_NUMBER() OVER (ORDER BY B.ASCII DESC)), 3, '0') AS NumericCode,
                TRIM(SUBSTR(A.Name, 1, INSTR(A.Name, ' (') - 1)) AS Name,
                TRIM(SUBSTR(A.NameFrench, 1, INSTR(A.NameFrench, ' (') - 1)) AS NameFrench,
                A.PropertyValueAlias,
                A.DateModified
                FROM S_S_ISO15924 A
                CROSS JOIN LOWERALPHABET B
                WHERE Name = 'Reserved for private use (end)'
                AND SUBSTR(A.ID, -1) > B.Chr
            )
            --
            MINUS
            --
            SELECT ID,
            NumericCode,
            Name,
            NameFrench,
            PropertyValueAlias,
            DateModified
            FROM LANGUAGESCRIPT
            ORDER BY 1
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.NumericCode = Y.NumericCode,
        X.Name = Y.Name,
        X.NameFrench = Y.NameFrench,
        X.PropertyValueAlias = Y.PropertyValueAlias,
        X.DateModified = Y.DateModified
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            DATEMODIFIED,
            NAME,
            NAMEFRENCH,
            NUMERICCODE,
            UUID,
            PROPERTYVALUEALIAS
        )
        VALUES
        (
            Y.ID,
            Y.DateModified,
            Y.Name,
            Y.NameFrench,
            Y.NumericCode,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.PropertyValueAlias
        );
        
        nRows := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('LANGUAGESCRIPT')
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
            WHERE Table_Name IN ('LANGUAGESCRIPT')
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
                OWNNAME=>'',
                TABNAME=>C.Table_Name,
                METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE=>TRUE,
                ESTIMATE_PERCENT=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nRows > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'LANGUAGESCRIPT' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('LANGUAGESCRIPT', vGoogleOutput);
                
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
        
        ROLLBACK;
        
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
    
    REFRESH_LANGUAGESCRIPT(0);
    
END;
/
*/