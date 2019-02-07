SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRYGDP
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRYGDP ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Download variables
    vURL VARCHAR2(32767 BYTE) := 'http://api.worldbank.org/v2/en/indicator/ny.gdp.mktp.cd?downloadformat=xml';
    
    --Document formatting variable
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    
    --Program variables
    cCLOB CLOB := EMPTY_CLOB();
    nDeletes PLS_INTEGER := 0;
    nMerges SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    xXML XMLTYPE;
    
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
        
        --Explictly set that the downloaded file will be a zip
        SAVE_DATA_FROM_URL
        (
            gURL=>vURL,
            gTableLookup_Name=>'COUNTRYGDP',
            gUnzip=>1
        );
        
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
                WHERE Table_Name IN ('COUNTRYGDP')
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
        || '<td>' || 'CREATE XML' || '</td>'
        || '<td>' || '' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            SELECT XMLPARSE(DOCUMENT Data) AS xXML
            INTO xXML
            FROM LATEST$INBOUND
            WHERE TableLookup_Name = 'COUNTRYGDP'
            AND URL = vURL;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'COUNTRYGDP' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO COUNTRYGDP X
        USING
        (
            SELECT Country_ID,
            Year,
            'USD' AS Currency_ID,
            GrossDomesticProduct
            FROM
            (
                SELECT ItemNo,
                Name,
                CASE
                    WHEN Name = 'Country or Area' THEN Key
                    ELSE Value
                END AS Value
                FROM
                (
                    SELECT A.ID AS ItemNo,
                    B.*
                    FROM XMLTABLE
                    (
                        '/Root/data/record' PASSING xXML
                        COLUMNS ID FOR ORDINALITY,
                        XML XMLTYPE PATH '.'
                    ) A
                    INNER JOIN XMLTABLE
                    (
                        '/record/field' PASSING A.XML
                        COLUMNS ID FOR ORDINALITY,
                        Name VARCHAR2(4000 BYTE) PATH '@name',
                        Key VARCHAR2(4000 BYTE) PATH '@key',
                        Value VARCHAR2(4000 BYTE) PATH '.'
                    ) B
                        ON 1 = 1
                )
            )
            PIVOT
            (
                MIN(Value) FOR Name IN
                (
                    'Country or Area' AS Country_ID,
                    'Year' AS Year,
                    'Value' AS GrossDomesticProduct
                )
            )
            WHERE GrossDomesticProduct IS NOT NULL
            --The country identifier is real
            AND Country_ID IN
            (
                SELECT ID
                FROM COUNTRY
            )
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Year = Y.Year
                    AND X.Currency_ID = Y.Currency_ID)
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            YEAR,
            CURRENCY_ID,
            GROSSDOMESTICPRODUCT
        )
        VALUES
        (
            Y.Country_ID,
            Y.Year,
            Y.Currency_ID,
            Y.GrossDomesticProduct
        )
        WHEN MATCHED THEN UPDATE SET X.GrossDomesticProduct = Y.GrossDomesticProduct
        WHERE X.GrossDomesticProduct != Y.GrossDomesticProduct;
        
        nMerges := nMerges + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'COUNTRYGDP' || '</td>'
        || '<td>' || TEXT_TO_HTML('Currency_ID = ''GBP''') || '</td>';
        
        MERGE
        INTO COUNTRYGDP X
        USING
        (
            SELECT A.Country_ID,
            A.Year,
            B.To$Currency_ID AS Currency_ID,
            ROUND(A.GrossDomesticProduct * B.Rate, 6) AS GrossDomesticProduct
            FROM COUNTRYGDP A
            INNER JOIN FULLYEARLY$FXRATE B
                ON A.Currency_ID = B.From$Currency_ID
                        AND 'GBP' = B.To$Currency_ID
                        AND A.Year = B.Year
            WHERE A.Currency_ID = 'USD'
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Year = Y.Year
                    AND X.Currency_ID = Y.Currency_ID)
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            YEAR,
            CURRENCY_ID,
            GROSSDOMESTICPRODUCT
        )
        VALUES
        (
            Y.Country_ID,
            Y.Year,
            Y.Currency_ID,
            Y.GrossDomesticProduct
        )
        WHEN MATCHED THEN UPDATE SET X.GrossDomesticProduct = Y.GrossDomesticProduct
        WHERE X.GrossDomesticProduct != Y.GrossDomesticProduct;
        
        nMerges := nMerges + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRYGDP')
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
            WHERE Table_Name IN ('COUNTRYGDP')
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
        
        IF nMerges > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRYGDP' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('COUNTRYGDP', vGoogleOutput);
                
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
--Odd character in front of the XML
SELECT DUMP(DBMS_LOB.SUBSTR(Data, 1, 1))
FROM INBOUND
WHERE TableLookup_Name = 'COUNTRYGDP';
--This is the Byte Order Mark - Oracle's XML parses safely ignores it

--Manual test of the XML parsing
WITH XML AS
(
    SELECT XMLPARSE(DOCUMENT Data) AS xXML
    --INTO xXML
    FROM INBOUND
    WHERE TableLookup_Name = 'COUNTRYGDP'
    AND URL = 'http://api.worldbank.org/v2/en/indicator/ny.gdp.mktp.cd?downloadformat=xml'
    AND DateTimeX =
    (
        SELECT MAX(DateTimeX)
        FROM INBOUND
        WHERE TableLookup_Name = 'COUNTRYGDP'
        AND URL = 'http://api.worldbank.org/v2/en/indicator/ny.gdp.mktp.cd?downloadformat=xml'
    )
)
--
SELECT Country_ID,
Year,
GrossDomesticProduct
FROM
(
    SELECT ItemNo,
    Name,
    CASE
        WHEN Name = 'Country or Area' THEN Key
        ELSE Value
    END AS Value
    FROM
    (
        SELECT A.ID AS ItemNo,
        B.*
        FROM XML
        INNER JOIN XMLTABLE('/Root/data/record' PASSING xXML
        COLUMNS ID FOR ORDINALITY,
        XML XMLTYPE PATH '.') A
            ON 1 = 1
        INNER JOIN XMLTABLE('/record/field' PASSING A.XML
        COLUMNS ID FOR ORDINALITY,
        Name VARCHAR2(4000 BYTE) PATH '@name',
        Key VARCHAR2(4000 BYTE) PATH '@key',
        Value VARCHAR2(4000 BYTE) PATH '.') B
            ON 1 = 1
    )
)
PIVOT
(
    MIN(Value)
    FOR Name IN
    (
        'Country or Area' AS Country_ID,
        'Year' AS Year,
        'Value' AS GrossDomesticProduct
    )
)
WHERE GrossDomesticProduct IS NOT NULL;

--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_COUNTRYGDP;
    
END;
/
*/