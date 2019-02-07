SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRY#CURRENCY
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRY#CURRENCY ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nDeleted SIMPLE_INTEGER := 0;
    nMerged SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
    --Error variables
    nErrorCode NUMBER := -1;
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'COUNTRY#CURRENCY' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM COUNTRY#CURRENCY
        WHERE (Country_ID, Currency_ID) IN
        (
            WITH S_COUNTRY#CURRENCY AS
            (
                SELECT Country_ID,
                Currency_ID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY Country_ID
                    ORDER BY DateEnd DESC,
                    CASE
                        WHEN Currency_ID IN ('CHE', 'CHW', 'CLF', 'COU', 'CUC', 'MXV', 'SVC', 'UYI', 'USN', 'USS', 'VNC') THEN 1
                        WHEN Currency_ID IN ('BTN', 'BOB', 'CSD', 'HTG', 'LSL', 'NAD', 'PAB') THEN -1
                        ELSE 0
                    END,
                    Currency_ID
                ) AS Rank
                FROM
                (
                    SELECT Currency_ID,
                    Country_ID,
                    MAX(COALESCE(DateEnd, TO_DATE('3000-01-01', 'YYYY-MM-DD'))) AS DateEnd
                    FROM
                    (
                        SELECT /*+ NO_QUERY_TRANSFORMATION */
                        TRIM(A.ID) AS Currency_ID,
                        B.Country_ID,
                        CASE
                            WHEN LENGTH(TRIM(A.DateEnd)) = 7 THEN TO_DATE(TRIM(A.DateEnd) || '-01', 'YYYY-MM-DD')
                            ELSE CASE
                                LENGTH(TRIM(SUBSTR(A.DateEnd, INSTR(DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))))
                                WHEN 4 THEN TO_DATE(TRIM(SUBSTR(A.DateEnd, INSTR(A.DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))) || '-01-01', 'YYYY-MM-DD')
                                WHEN 7 THEN TO_DATE(TRIM(SUBSTR(A.DateEnd, INSTR(A.DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))) || '-01', 'YYYY-MM-DD')
                                ELSE NULL
                            END
                        END AS DateEnd
                        FROM S_ISO4217 A
                        INNER JOIN UNIQUE$COUNTRYNAME B
                            ON TRIM(REGEXP_REPLACE(REGEXP_REPLACE(UPPER(TRIM(A.Entity)), '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]', ''), '[[:blank:]]{2,}',' ')) = B.Name
                        WHERE TRIM(A.ID) IS NOT NULL
                        AND SUBSTR(A.Entity, 1, 2) <> 'ZZ'
                    )
                    GROUP BY Currency_ID,
                    Country_ID
                )
            )
            --
            SELECT Country_ID,
            Currency_ID
            FROM COUNTRY#CURRENCY
            --
            MINUS
            --
            (
                SELECT Country_ID,
                Currency_ID
                FROM S_COUNTRY#CURRENCY
                --
                UNION ALL
                --
                SELECT B.ID AS Country_ID,
                A.Currency_ID
                FROM S_COUNTRY#CURRENCY A
                INNER JOIN COUNTRY B
                    ON A.Country_ID = B.Parent$Country_ID
                WHERE A.Rank = 1
                AND B.ID NOT IN
                (
                    SELECT Country_ID
                    FROM S_COUNTRY#CURRENCY
                    WHERE Rank = 1
                    AND Country_ID IS NOT NULL
                )
            )
        );
        
        nDeleted := nDeleted + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DISABLE CONSTRAINT' || '</td>'
        || '<td>' || 'COUNTRY#CURRENCY_UK' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE COUNTRY#CURRENCY DISABLE CONSTRAINT COUNTRY#CURRENCY_UK');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN 
            
            nErrorCode := SQLCode;
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            --Ignore ORA-02431: cannot disable constraint (COUNTRY#CURRENCY_UK) - no such constraint
            IF nErrorCode <> -2431 THEN
                
                RAISE HANDLED;
                
            END IF;
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'COUNTRY#CURRENCY' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO COUNTRY#CURRENCY X
        USING
        (
            WITH S_COUNTRY#CURRENCY AS
            (
                SELECT Country_ID,
                Currency_ID,
                ROW_NUMBER() OVER
                (
                    PARTITION BY Country_ID
                    ORDER BY DateEnd DESC,
                    CASE
                        WHEN Currency_ID IN ('CHE', 'CHW', 'CLF', 'COU', 'CUC', 'MXV', 'SVC', 'UYI', 'USN', 'USS', 'VNC') THEN 1
                        WHEN Currency_ID IN ('BTN', 'BOB', 'CSD', 'HTG', 'LSL', 'NAD', 'PAB') THEN -1
                        ELSE 0
                    END,
                    Currency_ID
                ) AS Rank
                FROM
                (
                    SELECT Currency_ID,
                    Country_ID,
                    MAX(COALESCE(DateEnd, TO_DATE('3000-01-01', 'YYYY-MM-DD'))) AS DateEnd
                    FROM
                    (
                        SELECT /*+ NO_QUERY_TRANSFORMATION */
                        TRIM(A.ID) AS Currency_ID,
                        B.Country_ID,
                        CASE
                            WHEN LENGTH(TRIM(A.DateEnd)) = 7 THEN TO_DATE(TRIM(A.DateEnd) || '-01', 'YYYY-MM-DD')
                            ELSE CASE
                                LENGTH(TRIM(SUBSTR(A.DateEnd, INSTR(DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))))
                                WHEN 4 THEN TO_DATE(TRIM(SUBSTR(A.DateEnd, INSTR(A.DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))) || '-01-01', 'YYYY-MM-DD')
                                WHEN 7 THEN TO_DATE(TRIM(SUBSTR(A.DateEnd, INSTR(A.DateEnd, 'to') + 2, LENGTH(A.DateEnd) - INSTR(A.DateEnd, 'to'))) || '-01', 'YYYY-MM-DD')
                                ELSE NULL
                            END
                        END AS DateEnd
                        FROM S_ISO4217 A
                        INNER JOIN UNIQUE$COUNTRYNAME B
                            ON TRIM(REGEXP_REPLACE(REGEXP_REPLACE(UPPER(TRIM(A.Entity)), '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]', ''), '[[:blank:]]{2,}',' ')) = B.Name
                        WHERE TRIM(A.ID) IS NOT NULL
                        AND SUBSTR(A.Entity, 1, 2) <> 'ZZ'
                    )
                    GROUP BY Currency_ID,
                    Country_ID
                )
            )
            --
            SELECT Country_ID,
            Currency_ID,
            Rank
            FROM S_COUNTRY#CURRENCY
            --
            UNION ALL
            --
            SELECT B.ID AS Country_ID,
            A.Currency_ID,
            A.Rank
            FROM S_COUNTRY#CURRENCY A
            INNER JOIN COUNTRY B
                ON A.Country_ID = B.Parent$Country_ID
            WHERE A.Rank = 1
            AND B.ID NOT IN
            (
                SELECT Country_ID
                FROM S_COUNTRY#CURRENCY
                WHERE Rank = 1
                AND Country_ID IS NOT NULL
            )
            --
            MINUS
            --
            SELECT Country_ID,
            Currency_ID,
            Rank
            FROM COUNTRY#CURRENCY
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Currency_ID = Y.Currency_ID)
        WHEN MATCHED THEN UPDATE SET X.Rank = Y.Rank
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            CURRENCY_ID,
            RANK
        )
        VALUES
        (
            Y.Country_ID,
            Y.Currency_ID,
            Y.Rank
        );
        
        nMerged := nMerged + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'ENABLE CONSTRAINT' || '</td>'
        || '<td>' || 'COUNTRY#CURRENCY_UK' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE COUNTRY#CURRENCY ENABLE CONSTRAINT COUNTRY#CURRENCY_UK');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN 
            
            nErrorCode := SQLCode;
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            --Ignore ORA-02430: cannot enable constraint (COUNTRY#CURRENCY_UK) - no such constraint
            IF nErrorCode <> -2430 THEN
                
                RAISE HANDLED;
                
            END IF;
            
        END;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRY#CURRENCY')
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
            WHERE Table_Name IN ('COUNTRY#CURRENCY')
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
                OWNNAME=> '',
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
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        IF nDeleted + nMerged > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRY#CURRENCY' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('COUNTRY#CURRENCY', vGoogleOutput);
                
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
    
    REFRESH_COUNTRY#CURRENCY;
    
END;
/
*/