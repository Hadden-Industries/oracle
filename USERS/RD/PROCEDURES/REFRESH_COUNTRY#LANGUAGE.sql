SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRY#LANGUAGE
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRY#LANGUAGE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nDeletes SIMPLE_INTEGER := 0;
    nInserts SIMPLE_INTEGER := 0;
    nUpdates SIMPLE_INTEGER := 0;
    rCOUNTRY#LANGUAGE COUNTRY#LANGUAGE%ROWTYPE;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'S_COUNTRY#LANGUAGE' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM S_COUNTRY#LANGUAGE;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'S_COUNTRY#LANGUAGE' || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT
        INTO S_COUNTRY#LANGUAGE
        (
            COUNTRY_ID,
            LANGUAGE_ID,
            RANK,
            NAMELOCALSHORT
        )
        --
        WITH S_COUNTRY AS
        (
            SELECT ID AS Country_ID,
            'https://www.iso.org/obp/ui/#iso:code:3166:' || Alpha2 AS URL
            FROM COUNTRY AS OF PERIOD FOR VALID_TIME TRUNC(SYSDATE)
        ),
        --
        XML AS
        (
            SELECT Country_ID,
            XMLPARSE
            (
                DOCUMENT REPLACE
                (
                    SUBSTR
                    (
                        Data,
                        Offset,
                        Position_End - Offset + LENGTH('</table>')
                    ),
                    '&nbsp;',
                    ' '
                )
            ) AS xXML
            FROM
            (
                SELECT B.Country_ID,
                DBMS_LOB.INSTR
                (
                    A.Data,
                    '<table>',
                    DBMS_LOB.INSTR(A.Data, '<div id="country-additional-info">', 1, 1),
                    1
                ) AS Offset,
                DBMS_LOB.INSTR
                (
                    A.Data,
                    '</table>',
                    DBMS_LOB.INSTR(A.Data, '<div id="country-additional-info">', 1, 1),
                    1
                ) AS Position_End,
                Data
                FROM LATEST$INBOUND A
                INNER JOIN S_COUNTRY B
                    ON A.URL = B.URL
            )
        )
        --
        SELECT A.Country_ID,
        COALESCE
        (
            B.ID,
            C.ID,
            D.ID,
            (
                SELECT ID
                FROM LANGUAGE
                WHERE Name = 'Undetermined'
            )
        ) AS Language_ID,
        A.ID,
        A.NameLocalShort
        FROM
        (
            SELECT Country_ID,
            ID,
            SINGLE_LINE(Language_Part1) AS Language_Part1,
            SINGLE_LINE(Language_Part2T) AS Language_Part2T,
            SINGLE_LINE(NameLocalShort) AS NameLocalShort
            FROM
            (
                SELECT XML.Country_ID,
                A.ID,
                B.ID_1,
                B.table_tbody_tr_td
                FROM XML
                INNER JOIN XMLTABLE
                (
                    '/table/tbody/tr' PASSING XML.xXML
                    COLUMNS ID FOR ORDINALITY,
                    table_tbody_tr XMLTYPE PATH '.'
                ) A
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/tr/td' PASSING A.table_tbody_tr
                    COLUMNS ID_1 FOR ORDINALITY,
                    table_tbody_tr_td VARCHAR2(4000 BYTE) PATH '.'
                ) B
                    ON 1 = 1
            )
            PIVOT
            (
                MIN(table_tbody_tr_td) FOR ID_1 IN
                (
                    1 AS Language_Part1,
                    2 AS Language_Part2T,
                    3 AS NameLocalShort
                )
            )
        ) A
        LEFT OUTER JOIN LANGUAGE B
            ON A.Language_Part1 = B.Part1
        LEFT OUTER JOIN LANGUAGE C
            ON A.Language_Part2T = C.Part2T
        LEFT OUTER JOIN LANGUAGE D
            ON A.Language_Part2T = D.ID;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'S_COUNTRY#LANGUAGE'
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'S_COUNTRY#LANGUAGE'
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
        || '<td>' || 'DISABLE' || '</td>'
        || '<td>' || 'CONSTRAINT' || '</td>'
        || '<td>' || 'COUNTRY#LANGUAGE_RANK_UK' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE COUNTRY#LANGUAGE DISABLE CONSTRAINT COUNTRY#LANGUAGE_RANK_UK');
            
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
           SELECT Country_ID,
            Language_ID,
            Rank,
            NameLocalShort
            FROM COUNTRY#LANGUAGE
            WHERE (Country_ID, Language_ID) NOT IN
            (
                SELECT Country_ID,
                Language_ID
                FROM S_COUNTRY#LANGUAGE
            )
            ORDER BY Country_ID,
            Language_ID
        ) LOOP
            
            vMsg := vMsg || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'COUNTRY#LANGUAGE' || '</td>'
            || '<td>' || C.Country_ID || ',' || C.Language_ID || ',' || TO_CHAR(C.Rank) || ',' || TEXT_TO_HTML(C.NameLocalShort) || '</td>';
            
            DELETE
            FROM COUNTRY#LANGUAGE
            WHERE Country_ID = C.Country_ID
            AND Language_ID = C.Language_ID;
            
            nDeletes := nDeletes + SQL%ROWCOUNT;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Country_ID,
            Rank,
            Language_ID,
            NameLocalShort
            FROM S_COUNTRY#LANGUAGE
            --
            MINUS
            --
            SELECT Country_ID,
            Rank,
            Language_ID,
            NameLocalShort
            FROM COUNTRY#LANGUAGE
            WHERE Country_ID IN
            (
                SELECT Country_ID
                FROM S_COUNTRY#LANGUAGE
            )
            ORDER BY Country_ID,
            Language_ID
        ) LOOP
            
            BEGIN
                
                SELECT *
                INTO rCOUNTRY#LANGUAGE
                FROM COUNTRY#LANGUAGE
                WHERE Country_ID = C.Country_ID
                AND Language_ID = C.Language_ID;
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'UPDATE' || '</td>'
                || '<td>' || 'COUNTRY#LANGUAGE' || '</td>'
                || '<td>' || C.Country_ID || ',' || C.Language_ID || ' (' || TO_CHAR(rCOUNTRY#LANGUAGE.Rank) || '=>' || TO_CHAR(C.Rank) || ',' || TEXT_TO_HTML(rCOUNTRY#LANGUAGE.NameLocalShort) || '=>' || TEXT_TO_HTML(C.NameLocalShort) || ')' || '</td>';
                
                UPDATE
                COUNTRY#LANGUAGE
                SET Rank = C.Rank,
                NameLocalShort = C.NameLocalShort
                WHERE Country_ID = C.Country_ID
                AND Language_ID = C.Language_ID;
                
                nUpdates := nUpdates + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            EXCEPTION
            --No row exists in the original
            WHEN NO_DATA_FOUND THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'COUNTRY#LANGUAGE' || '</td>'
                || '<td>' || C.Country_ID || ',' || C.Language_ID || ',' || TO_CHAR(C.Rank) || ',' || TEXT_TO_HTML(C.NameLocalShort) || '</td>';
                
                INSERT
                INTO COUNTRY#LANGUAGE
                (
                    COUNTRY_ID,
                    LANGUAGE_ID,
                    RANK,
                    NAMELOCALSHORT
                )
                VALUES
                (
                    C.Country_ID,
                    C.Language_ID,
                    C.Rank,
                    C.NameLocalShort
                );
                
                nInserts := nInserts + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END;
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'COUNTRY#LANGUAGE'
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'ENABLE' || '</td>'
        || '<td>' || 'CONSTRAINT' || '</td>'
        || '<td>' || 'COUNTRY#LANGUAGE_RANK_UK' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE COUNTRY#LANGUAGE ENABLE CONSTRAINT COUNTRY#LANGUAGE_RANK_UK');
            
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
            WHERE Table_Name IN
            (
                'COUNTRY#LANGUAGE'
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
        
        
        IF nDeletes + nInserts + nUpdates > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRY#LANGUAGE' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('COUNTRY#LANGUAGE', vGoogleOutput);
                
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
    
    REFRESH_COUNTRY#LANGUAGE;
    
END;
/
*/