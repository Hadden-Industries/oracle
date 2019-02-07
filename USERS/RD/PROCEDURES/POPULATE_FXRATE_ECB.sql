SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE POPULATE_FXRATE_ECB
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'Populate FXRATE ECB ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    dMinDate DATE;
    nRowsMerged INTEGER := 0;
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    vURL VARCHAR2(4000 BYTE) := 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.xml';
    
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL, 'FXRATE');
            
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
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'FXRATE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO FXRATE X
        USING
        (
            WITH XML AS
            (
                SELECT XMLPARSE(DOCUMENT Data) AS xXML
                FROM LATEST$INBOUND
                WHERE TableLookup_Name = 'FXRATE'
                AND URL = vURL
            ),
            --
            A AS
            (
                SELECT A.Subject,
                A.Sender_Name,
                A.Cube_Cube
                FROM XML
                INNER JOIN XMLTABLE
                (
                    XMLNAMESPACES
                    (
                        'http://www.gesmes.org/xml/2002-08-01' AS "gesmes",
                        'http://www.ecb.int/vocabulary/2002-08-01/eurofxref' AS "a"
                    ),
                    '/gesmes:Envelope' PASSING XML.xXML
                    COLUMNS Subject CHAR(15) PATH 'gesmes:subject',
                    Sender_Name CHAR(21) PATH 'gesmes:Sender/gesmes:name',
                    Cube_Cube XMLTYPE PATH 'a:Cube/a:Cube'
                ) A
                    ON 1 = 1
            ),
            --
            B AS
            (
                SELECT B.Cube_Cube_Time,
                B.Cube_Cube_Cube
                FROM A
                INNER JOIN XMLTABLE
                (
                    XMLNAMESPACES('http://www.ecb.int/vocabulary/2002-08-01/eurofxref' as "a"),
                    '/a:Cube' PASSING A.Cube_Cube
                    COLUMNS Cube_Cube_Time DATE PATH '@time',
                    Cube_Cube_Cube XMLTYPE PATH 'a:Cube'
                ) B
                    ON 1 = 1
            ),
            --
            C AS
            (
                SELECT B.Cube_Cube_Time,
                C.Currency,
                C.Rate
                FROM B,
                XMLTABLE
                (
                    XMLNAMESPACES('http://www.ecb.int/vocabulary/2002-08-01/eurofxref' as "b"),
                    --'(#ora:view_on_null empty #) {b:Cube/*:Cube}' PASSING A.Cube, --will treat empty elements as empty rather than not existing
                    'b:Cube' PASSING B.Cube_Cube_Cube
                    COLUMNS Currency CHAR(3 CHAR) PATH '@currency',
                    Rate NUMBER PATH '@rate'
                ) (+) C
            )
            --
            SELECT /*+ ORDERED */
            'EUR' AS From$Currency_ID,
            C.Currency AS To$Currency_ID,
            (
                SELECT ID
                FROM FXRATETYPE
                WHERE Name = 'Mid'
            ) AS FXRateType_ID,
            (C.Cube_Cube_time + (13/24) + (15/(24 * 60))) AS DateTimeX,
            C.Rate
            FROM C
            INNER JOIN CURRENCY D
                --Ensure that the currency ID exists
                ON  C.Currency = D.ID
                        --Currency is valid at that time
                        AND
                        (
                            D.DateStart IS NULL
                            OR
                            D.DateStart <= C.Cube_Cube_Time
                        )
                        AND
                        (
                            D.DateEnd IS NULL
                            OR
                            D.DateEnd >= C.Cube_Cube_Time
                        )
            --the rate is positive and greater than zero
            WHERE C.Rate > 0
        ) Y
            ON (X.From$Currency_ID = Y.From$Currency_ID
                    AND X.To$Currency_ID = Y.To$Currency_ID
                    AND X.DateX = TRUNC(Y.DateTimeX)
                    AND X.FXRateType_ID = Y.FXRateType_ID)
        WHEN MATCHED THEN UPDATE SET X.DateTimeBasis = Y.DateTimeX,
        X.DateTimeX = Y.DateTimeX,
        X.Rate = Y.Rate
        WHERE X.DateTimeBasis <> Y.DateTimeX
        OR X.DateTimeX <> Y.DateTimeX
        OR X.Rate <> Y.Rate
        WHEN NOT MATCHED THEN INSERT
        (
            FROM$CURRENCY_ID,
            TO$CURRENCY_ID,
            FXRATETYPE_ID,
            DATETIMEBASIS,
            DATETIMEX,
            RATE
        )
        VALUES
        (
            Y.From$Currency_ID,
            Y.To$Currency_ID,
            Y.FXRateType_ID,
            Y.DateTimeX,
            Y.DateTimeX,
            Y.Rate
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        SELECT COALESCE
        (
            MIN(DateX),
            TO_DATE('1999-01-04', 'YYYY-MM-DD')
        )
        INTO dMinDate
        FROM FXRATE
        WHERE From$Currency_ID = 'EUR';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'FXRATE' || '</td>'
        || '<td>' || 'Gaps in interval ' || TO_CHAR(dMinDate, 'YYYY-MM-DD')  || '/' || TO_CHAR(TRUNC(SYSDATE), 'YYYY-MM-DD') || '</td>';
        
        MERGE_FXRATE_GAPS(dMinDate, TRUNC(SYSDATE), nRowsMerged);
        
        vMsg := vMsg || '<td>' || TO_CHAR(nRowsMerged) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('FXRATE')
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
            WHERE Table_Name IN ('FXRATE')
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
                ownname=>NULL,
                tabname=>C.Table_Name,
                method_opt=>'FOR ALL COLUMNS SIZE SKEWONLY',
                cascade=>TRUE,
                estimate_percent=>100
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
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    POPULATE_FXRATE_ECB;
    
END;
/
*/