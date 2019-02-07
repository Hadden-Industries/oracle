SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

--added gDownload parameter because of ORA-24263: Certificate of the remote server does not match the target address.

CREATE OR REPLACE
PROCEDURE REFRESH_CURRENCY(gDownload INTEGER DEFAULT 0)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'CURRENCY ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nAnythingToUpdate SIMPLE_INTEGER := 1;
    nDeleted SIMPLE_INTEGER := 0;
    nMerged SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    vURLCurrent CONSTANT VARCHAR2(100 BYTE) := 'https://www.currency-iso.org/dam/downloads/lists/list_one.xml';
    vURLHistoric CONSTANT VARCHAR2(100 BYTE) := 'https://www.currency-iso.org/dam/downloads/lists/list_three.xml';
    xXML XMLTYPE;
    
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_CURRENCYINFO')
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
        
        
        IF gDownload > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || '(Current)' || '</td>';
            
            BEGIN
                
                SAVE_DATA_FROM_URL(vURLCurrent, 'CURRENCY');
                
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
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(vURLCurrent) || '</td>';
            
            DELETE_INBOUND_DUPLICATE(vURLCurrent);
            
            nDeleted := nDeleted + SQL%ROWCOUNT;
            
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
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'VALIDATE' || '</td>'
        || '<td>' || 'XML' || '</td>'
        || '<td>' || '(Current)' || '</td>';
        
        SELECT XMLPARSE(DOCUMENT X.Data) AS XML
        INTO xXML
        FROM LATEST$INBOUND X
        WHERE X.TableLookup_Name = 'CURRENCY'
        AND X.URL = vURLCurrent;
        
        IF xXML.isSchemaValid('ISO_4217.xsd') = 1 THEN
            
            xXML.setSchemaValidated(1);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        ELSE
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
            || '</tr>';
            
            --RAISE HANDLED; --Do not raise an error as Oracle sometimes fails validation even if the data is correct
            
        END IF;
        
        
        IF gDownload > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || '(Historic)' || '</td>';
            
            BEGIN
                
                SAVE_DATA_FROM_URL(vURLHistoric, 'CURRENCY');
                
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
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(vURLHistoric) || '</td>';
            
            DELETE_INBOUND_DUPLICATE(vURLHistoric);
            
            nDeleted := nDeleted + SQL%ROWCOUNT;
            
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
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'VALIDATE' || '</td>'
        || '<td>' || 'XML' || '</td>'
        || '<td>' || '(Historic)' || '</td>';
        
        SELECT XMLPARSE(DOCUMENT X.Data) AS XML
        INTO xXML
        FROM LATEST$INBOUND X
        WHERE X.TableLookup_Name = 'CURRENCY'
        AND X.URL = vURLHistoric;
        
        IF xXML.IsSchemaValid('ISO_4217.xsd') = 1 THEN
            
            xXML.SetSchemaValidated(1);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        ELSE
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
            || '</tr>';
            
            --RAISE HANDLED; --Do not raise an error as Oracle sometimes fails validation even if the data is correct
            
        END IF;
        
        
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
        
        
        IF nDeleted = 2 THEN --If deleted both new rows as they were the same as the previous set
            
            nAnythingToUpdate := 0; --Assert that there is nothing to update
            
            BEGIN
                
                SELECT 1
                INTO nAnythingToUpdate --Refute assertion if S_CURRENCYINFO table is fresher than CURRENCY
                FROM TABLELOOKUP
                WHERE Name = 'S_CURRENCYINFO'
                AND DateTimeUpdated >
                (
                    SELECT DateTimeUpdated
                    FROM TABLELOOKUP
                    WHERE Name = 'CURRENCY'
                );
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN --OK to find no rows if S_CURRENCYINFO table is not fresher than CURRENCY
                
                NULL;
                
            END;
            
            IF nAnythingToUpdate = 0 THEN
                
                FOR C IN
                (
                    SELECT Table_Name
                    FROM USER_TABLES
                    WHERE Table_Name IN ('CURRENCY')
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
                
                RAISE HANDLED;
                
            END IF;
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'CURRENCY' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO CURRENCY X
        USING
        (
            WITH STAGING AS
            (
                SELECT A.ID,
                A.Name,
                A.Fund,
                A.MinorUnit,
                A.NumericCode,
                B.Symbol,
                COALESCE(B.DateStart, A.DateStart) AS DateStart,
                COALESCE(B.DateEnd, A.DateEnd) AS DateEnd,
                CASE
                    WHEN A.Fund = 'T' THEN B.Comments
                    ELSE A.Comments
                END AS Comments
                FROM
                (
                    SELECT ID,
                    Name,
                    Fund,
                    NumericCode,
                    MinorUnit,
                    DateStart,
                    DateEnd,
                    Comments,
                    ROW_NUMBER() OVER (PARTITION BY ID ORDER BY COALESCE(DateEnd, TO_DATE('3000-01-01', 'YYYY-MM-DD')) DESC) AS RN
                    FROM
                    (
                        SELECT Entity,
                        Name,
                        Fund,
                        ID,
                        NumericCode,
                        MinorUnit,
                        CASE
                            WHEN INSTR(DateEnd, 'to') > 0 THEN CASE LENGTH(TRIM(SUBSTR(DateEnd, 1, INSTR(DateEnd, 'to') - 2)))
                                WHEN 4 THEN TO_DATE(TRIM(SUBSTR(DateEnd, 1, INSTR(DateEnd, 'to') - 2)) || '-01-01', 'YYYY-MM-DD')
                                WHEN 7 THEN TO_DATE(TRIM(SUBSTR(DateEnd, 1, INSTR(DateEnd, 'to') - 2)) || '-01', 'YYYY-MM-DD')
                                ELSE NULL
                            END
                            ELSE NULL
                        END AS DateStart,
                        (
                            ADD_MONTHS
                            (
                                CASE
                                    WHEN LENGTH(TRIM(DateEnd)) = 7 THEN TO_DATE(TRIM(DateEnd) || '-01', 'YYYY-MM-DD')
                                    ELSE CASE LENGTH(TRIM(SUBSTR(DateEnd, INSTR(DateEnd, 'to') + 2, LENGTH(DateEnd) - INSTR(DateEnd, 'to'))))
                                        WHEN 4 THEN TO_DATE(TRIM(SUBSTR(DateEnd, INSTR(DateEnd, 'to') + 2, LENGTH(DateEnd) - INSTR(DateEnd, 'to'))) || '-01-01', 'YYYY-MM-DD')
                                        WHEN 7 THEN TO_DATE(TRIM(SUBSTR(DateEnd, INSTR(DateEnd, 'to') + 2, LENGTH(DateEnd) - INSTR(DateEnd, 'to'))) || '-01', 'YYYY-MM-DD')
                                        ELSE NULL
                                    END
                                END,
                                1
                            ) -1
                        ) AS DateEnd,
                        Comments
                        FROM S_ISO4217
                        WHERE ID IS NOT NULL
                    )
                ) A
                LEFT OUTER JOIN S_CURRENCYINFO B
                    ON A.ID = B.Currency_ID
                WHERE A.RN = 1
            )
            --
            SELECT ID,
            Name,
            Fund,
            MinorUnit,
            NumericCode,
            Symbol,
            DateStart,
            DateEnd,
            Comments
            FROM STAGING
            WHERE ID IS NOT NULL
            AND Name IS NOT NULL
            AND Fund IS NOT NULL
            AND (ID, Name, Fund, COALESCE(MinorUnit, -1), COALESCE(NumericCode, '-1'), COALESCE(Symbol, '-1'), COALESCE(DateStart, TO_DATE('0001-01-01', 'YYYY-MM-DD')), COALESCE(DateEnd, TO_DATE('9999-12-31', 'YYYY-MM-DD')), COALESCE(Comments, '-1')) NOT IN
            (
                SELECT ID,
                Name,
                Fund,
                COALESCE(MinorUnit, -1),
                COALESCE(NumericCode, '-1'),
                COALESCE(Symbol, '-1'),
                COALESCE
                (
                    DateStart,
                    TO_DATE('0001-01-01', 'YYYY-MM-DD')
                ),
                COALESCE
                (
                    DateEnd,
                    TO_DATE('9999-12-31', 'YYYY-MM-DD')
                ),
                COALESCE(Comments, '-1')
                FROM CURRENCY
            )
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Fund = Y.Fund,
        X.Name = Y.Name,
        X.DateEnd = Y.DateEnd,
        X.DateStart = Y.DateStart,
        X.MinorUnit = Y.MinorUnit,
        X.NumericCode = Y.NumericCode,
        X.Symbol = Y.Symbol,
        X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            FUND,
            NAME,
            UUID,
            DATEEND,
            DATESTART,
            MINORUNIT,
            NUMERICCODE,
            SYMBOL,
            COMMENTS
        )
        VALUES
        (
            Y.ID,
            Y.Fund,
            Y.Name,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.DateEnd,
            Y.DateStart,
            Y.MinorUnit,
            Y.NumericCode,
            Y.Symbol,
            Y.Comments
        );
        
        nMerged := nMerged + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('CURRENCY')
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
            WHERE Table_Name IN ('CURRENCY')
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
        
        
        IF nMerged > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'CURRENCY' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('CURRENCY', vGoogleOutput);
                
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
    
    REFRESH_CURRENCY;
    
END;
/
*/