SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE POPULATE_FXRATE_BOE
(
    gFrom$Currency_ID IN CHAR DEFAULT 'GBP',
    gTo$Currency_ID IN CHAR DEFAULT 'USD',
    --Earliest year accepted by API is 1963
    gDateFrom IN DATE DEFAULT TO_DATE('1963-01-01', 'YYYY-MM-DD'),
    gDateTo IN DATE DEFAULT TO_DATE('1999-01-03', 'YYYY-MM-DD')
)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'Populate FXRATE BoE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    dLastGapDay DATE;
    nRowsMerged INTEGER := 0;
    vSeriesCode VARCHAR2(7 BYTE) := '';
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    vURLBase VARCHAR2(4000 BYTE) := 'http://www.bankofengland.co.uk/boeapps/iadb/fromshowcolumns.asp?CodeVer=new&xml.x=yes';
    
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
        || '<td>' || TO_CHAR(gDateFrom, 'YYYY-MM-DD') || '/' || TO_CHAR(gDateTo, 'YYYY-MM-DD') || '</td>';
        
        BEGIN
            
            IF
            (
                gFrom$Currency_ID = 'GBP'
                AND gTo$Currency_ID = 'USD'
            ) THEN
                
                vSeriesCode := 'XUDLUSS';
                
            ELSE
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('The currency conversion of ' || gFrom$Currency_ID || '->' || gTo$Currency_ID || ' is not currently supported') || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END IF;
            
            SAVE_DATA_FROM_URL(vURLBase || '&Datefrom=' || TO_CHAR(gDateFrom, 'DD/Mon/YYYY') || '&Dateto=' || TO_CHAR(gDateTo, 'DD/Mon/YYYY') || '&SeriesCodes=' || vSeriesCode, 'FXRATE');
            
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
                FROM INBOUND
                WHERE TableLookup_Name = 'FXRATE'
                AND URL LIKE vURLBase || '%'
                AND DateTimeX =
                (
                    SELECT MAX(DateTimeX)
                    FROM INBOUND
                    WHERE TableLookup_Name = 'FXRATE'
                    AND URL LIKE vURLBase || '%'
                )
            ),
            --
            RESULTS AS
            (
                SELECT gTo$Currency_ID AS From$Currency_ID,
                gFrom$Currency_ID AS To$Currency_ID,
                A.DateTimeX,
                --"The data represent indicative middle market (mean of spot buying and selling) rates" http://www.bankofengland.co.uk/statistics/pages/iadb/notesiadb/Spot_rates.aspx
                (
                    SELECT ID
                    FROM FXRATETYPE
                    WHERE Name = 'Mid'
                ) AS FXRateType_ID,
                --Reciprocal as we have the GBP->USD rates
                (1/A.Rate) AS Rate
                FROM XML
                --Namespaces are important!
                INNER JOIN XMLTABLE
                (
                    XMLNAMESPACES
                    (
                        'http://www.gesmes.org/xml/2002-08-01' AS "gesmes",
                        'http://www.bankofengland.co.uk/boeapps/iadb/agg_series' AS "a"
                    ),
                    '/gesmes:Envelope/a:Cube/a:Cube' PASSING XML.xXML
                    COLUMNS DateTimeX DATE PATH '@TIME',
                    Rate NUMBER PATH '@OBS_VALUE'
                ) A
                    ON 1 = 1
                --Only up to the last point where we used the USD as base currency
                --Some of the Cube values are metadata, so exclude them (Comparison implictly assumes a NOT NULL value)
                WHERE A.DateTimeX <=
                (
                    SELECT COALESCE
                    (
                        MAX(DateX),
                        TO_DATE('1999-01-03', 'YYYY-MM-DD')
                    )
                    FROM FXRATE
                    WHERE From$Currency_ID = 'USD'
                )
                --The rate is positive and greater than zero
                AND A.Rate > 0
            )
            --
            SELECT From$Currency_ID,
            To$Currency_ID,
            FXRateType_ID,    
            DateTimeX AS DateTimeBasis,
            DateTimeX,
            Rate
            FROM RESULTS A
        ) Y
            ON (X.From$Currency_ID = Y.From$Currency_ID
                    AND X.To$Currency_ID = Y.To$Currency_ID
                    AND X.DateX = TRUNC(Y.DateTimeX)
                    AND X.FXRateType_ID = Y.FXRateType_ID)
        WHEN MATCHED THEN UPDATE SET X.DateTimeBasis = Y.DateTimeBasis,
        X.DateTimeX = Y.DateTimeX,
        X.Rate = Y.Rate
        WHERE X.DateTimeBasis <> Y.DateTimeBasis
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
            Y.DateTimeBasis,
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
        - 2 AS dLastGapDay
        INTO dLastGapDay
        FROM FXRATE
        WHERE From$Currency_ID = 'EUR';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'FXRATE' || '</td>'
        || '<td>' || 'Gaps in interval ' || TO_CHAR(gDateFrom, 'YYYY-MM-DD')  || '/' || TO_CHAR(dLastGapDay, 'YYYY-MM-DD') || '</td>';
        
        MERGE_FXRATE_GAPS(gDateFrom, dLastGapDay, nRowsMerged);
        
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
    
    POPULATE_FXRATE_BOE;
    
END;
/
*/