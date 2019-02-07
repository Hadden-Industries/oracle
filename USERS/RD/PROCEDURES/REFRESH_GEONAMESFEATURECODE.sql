SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GEONAMESFEATURECODE(gDownload IN INTEGER DEFAULT 1)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'GEONAMESFEATURECODE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vURL VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/featureCodes_en.txt';
    cCLOB CLOB := EMPTY_CLOB();
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    nDeletes PLS_INTEGER := 0;
    
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
        
        
        IF (gDownload = 1) THEN
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL, 'GEONAMESFEATURECODE');
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'ROLLBACK' || '</td>'
            || '<td>' || USER || '</td>'
            || '<td>' || '' || '</td>';
            
            ROLLBACK;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'TABLELOOKUP' || '</td>'
        || '<td>' || 'INBOUND' || '</td>';
        
        TOUCH('INBOUND');
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL);
        
        nDeletes := nDeletes + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF nDeletes > 0 THEN
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN
                (
                    'GEONAMESFEATURECLASS',
                    'GEONAMESFEATURECODE',
                    'S_GEONAMESFEATURECODE'
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
        || '<td>' || 'TRUNCATE' || '</td>'
        || '<td>' || 'S_GEONAMESFEATURECODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            UTL_FILE.FRemove('RD', 'S_GEONAMESFEATURECODE.tsv');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'S_GEONAMESFEATURECODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT A.Data
        INTO cCLOB
        FROM LATEST$INBOUND A
        WHERE A.TableLookup_Name = 'GEONAMESFEATURECODE'
        AND A.URL = vURL;
        
        CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESFEATURECODE.tsv');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'TABLELOOKUP' || '</td>'
        || '<td>' || 'S_GEONAMESFEATURECODE' || '</td>';
        
        TOUCH('S_GEONAMESFEATURECODE');
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        END IF; --Ending if Download
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GEONAMESFEATURECLASS' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO GEONAMESFEATURECLASS X
        USING
        (
            SELECT DISTINCT
            SUBSTR(ID, 1, 1) AS ID,
            CASE SUBSTR(ID, 1, 1)
                WHEN 'A' THEN 'Country, state, region,...'
                WHEN 'H' THEN 'Stream, lake,...'
                WHEN 'L' THEN 'Parks, area,...'
                WHEN 'P' THEN 'City, village,...'
                WHEN 'R' THEN 'Road, railroad'
                WHEN 'S' THEN 'Spot, building, farm'
                WHEN 'T' THEN 'Mountain, hill, rock,...'
                WHEN 'U' THEN 'Undersea'
                WHEN 'V' THEN 'Forest, heath,...'
                WHEN 'n' THEN 'Not available'
                ELSE SUBSTR(ID, 1, 1)
            END AS Name,
            NULL AS Comments
            FROM S_GEONAMESFEATURECODE
            WHERE ID != 'null'
            --
            MINUS
            --
            SELECT ID,
            Name,
            Comments
            FROM GEONAMESFEATURECLASS
            ORDER BY ID
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Name = Y.Name,
        X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            NAME,
            UUID,
            COMMENTS
        )
        VALUES
        (
            Y.ID,
            Y.Name,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.Comments
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'GEONAMESFEATURECLASS' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            DELETE
            FROM GEONAMESFEATURECLASS X
            WHERE ID IN
            (
                SELECT ID
                FROM
                (
                    SELECT ID,
                    Name,
                    Comments
                    FROM GEONAMESFEATURECLASS
                    --
                    MINUS
                    --
                    SELECT DISTINCT
                    SUBSTR(ID, 1, 1) AS ID,
                    CASE SUBSTR(ID, 1, 1)
                        WHEN 'A' THEN 'Country, state, region,...'
                        WHEN 'H' THEN 'Stream, lake,...'
                        WHEN 'L' THEN 'Parks, area,...'
                        WHEN 'P' THEN 'City, village,...'
                        WHEN 'R' THEN 'Road, railroad'
                        WHEN 'S' THEN 'Spot, building, farm'
                        WHEN 'T' THEN 'Mountain, hill, rock,...'
                        WHEN 'U' THEN 'Undersea'
                        WHEN 'V' THEN 'Forest, heath,...'
                        WHEN 'n' THEN 'Not available'
                        ELSE SUBSTR(ID, 1, 1)
                    END AS Name,
                    NULL AS Comments
                    FROM S_GEONAMESFEATURECODE
                    WHERE ID != 'null'
                )
            );
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'TABLELOOKUP' || '</td>'
        || '<td>' || 'GEONAMESFEATURECLASS' || '</td>';
        
        TOUCH('GEONAMESFEATURECLASS');
        
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'GEONAMESFEATURECLASS'
            )
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GEONAMESFEATURECODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO GEONAMESFEATURECODE X
        USING
        (
            SELECT SUBSTR(ID, 3) AS ID,
            SUBSTR(ID, 1, 1) AS GeoNamesFeatureClass_ID,
            Name,
            Comments
            FROM S_GEONAMESFEATURECODE
            WHERE ID != 'null'
            --
            MINUS
            --
            SELECT ID,
            GeoNamesFeatureClass_ID,
            Name,
            Comments
            FROM GEONAMESFEATURECODE
            ORDER BY GeoNamesFeatureClass_ID,
            ID
        ) Y
        ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.GeoNamesFeatureClass_ID = Y.GeoNamesFeatureClass_ID,
        X.Name = Y.Name,
        X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            GEONAMESFEATURECLASS_ID,
            NAME,
            UUID,
            COMMENTS
        )
        VALUES
        (
            Y.ID,
            Y.GeoNamesFeatureClass_ID,
            Y.Name,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.Comments
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'GEONAMESFEATURECODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            DELETE
            FROM GEONAMESFEATURECODE X
            WHERE ID IN
            (
                SELECT ID
                FROM
                (
                    SELECT ID,
                    GeoNamesFeatureClass_ID,
                    Name,
                    Comments
                    FROM GEONAMESFEATURECODE
                    --
                    MINUS
                    --
                    SELECT SUBSTR(ID, 3) AS ID,
                    SUBSTR(ID, 1, 1) AS GeoNamesFeatureClass_ID,
                    Name,
                    Comments
                    FROM S_GEONAMESFEATURECODE
                    WHERE ID != 'null'
                )
            );
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'TABLELOOKUP' || '</td>'
        || '<td>' || 'GEONAMESFEATURECODE' || '</td>';
        
        TOUCH('GEONAMESFEATURECODE');
        
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'GEONAMESFEATURECODE'
            )
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
    
    REFRESH_GEONAMESFEATURECODE(0);
    
END;
/
*/