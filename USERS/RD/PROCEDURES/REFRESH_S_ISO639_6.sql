SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_S_ISO639_6
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'S_ISO639_6 ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    cTmp CLOB := EMPTY_CLOB();
    nDeleted SIMPLE_INTEGER := 0;
    nMerged SIMPLE_INTEGER := 0;
    vURL CONSTANT VARCHAR2(4000 BYTE) := 'http://www.geolang.com/iso639-6/sortAlpha4.asp';
    xXML XMLTYPE;
    
    --Document formatting variable
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
        
        
        FOR C IN
        (
            SELECT vURL || '?selectA4letter=' || ASCII.UnicodeCharacter || '&viewAlpha4=View' AS URL,
            ASCII.UnicodeCharacter
            FROM
            (
                SELECT (IDFrom + LEVEL - 1) AS ASCII_ID
                FROM
                (
                    SELECT ASCII('a') AS IDFrom,
                    ASCII('z') AS IDTo
                    FROM DUAL
                )
                CONNECT BY LEVEL <= (IDTo - IDFrom + 1)
            ) A
            INNER JOIN ASCII
                ON A.ASCII_ID = ASCII.ID
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(C.URL) || '</td>';
            
            BEGIN
                
                SAVE_DATA_FROM_URL
                (
                    gURL => C.URL,
                    gTableLookup_Name => 'S_ISO639_6',
                    gMethod => 'POST',
                    gCharacterSet => 'WE8ISO8859P1'
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
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'INBOUND' || '</td>'
            || '<td>' || TEXT_TO_HTML(C.URL) || '</td>';
            
            DELETE_INBOUND_DUPLICATE(C.URL);
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
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
            
            
            FOR D IN
            (
                SELECT Offset,
                Position_End - Offset + LENGTH('</table>') AS Amount,
                Data
                FROM
                (
                    --Second table
                    SELECT DBMS_LOB.INSTR(Data, '<table', 1, 2) AS Offset,
                    --Second table
                    DBMS_LOB.INSTR(Data, '</table>', 1, 2) AS Position_End,
                    Data
                    FROM LATEST$INBOUND X
                    WHERE X.TableLookup_Name = 'S_ISO639_6'
                    AND X.URL = C.URL
                )
            ) LOOP
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'CREATE' || '</td>'
                || '<td>' || 'Table CLOB' || '</td>'
                || '<td>' || '' || '</td>';
                
                DBMS_LOB.CreateTemporary(cTmp, TRUE);
                
                DBMS_LOB.Copy(cTmp, D.Data, D.Amount, 1, D.Offset);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            END LOOP; --End loop to find second table
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CREATE' || '</td>'
            || '<td>' || 'XML' || '</td>'
            || '<td>' || '' || '</td>';
            
            BEGIN
                
                SELECT XMLTRANSFORM
                (
                    XMLPARSE
                    (
                        DOCUMENT REPLACE
                        (
                            UNESCAPE_REFERENCE_CLOB(cTmp),
                            '&',
                            '&amp;'
                        )
                    ),
                    XSLT.XML
                ) AS xXML
                INTO xXML
                FROM XSLT
                WHERE Name = 'REMOVE_COMMENTS';
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'S_ISO639_6' || '</td>'
            || '<td>' || '' || '</td>';
            
            DELETE
            FROM S_ISO639_6
            WHERE ID IN
            (
                SELECT A.ID
                FROM S_ISO639_6 A
                LEFT OUTER JOIN
                (
                    SELECT REPLACE(Language_ID,' ') AS ID
                    FROM
                    (
                        SELECT A.ID AS ID_0,
                        B.ID ID_1,
                        B.td
                        FROM
                        /*(SELECT XMLTRANSFORM(XMLPARSE(DOCUMENT REPLACE(UNESCAPE_REFERENCE_CLOB(Data), '&', '&amp;')), (SELECT XML FROM XSLT WHERE Name = 'REMOVE_COMMENTS')) AS xXML
                        FROM INBOUND
                        WHERE TableLookup_Name = 'S_ISO639_6'
                        AND DateTimeX = '2013-06-10T12:47:03') XML
                        INNER JOIN*/ XMLTABLE
                        (
                            '/table/tr' PASSING xXML
                            COLUMNS ID FOR ORDINALITY,
                            tr_td XMLTYPE PATH 'td'
                        ) A
                        --    ON 1 = 1
                        INNER JOIN XMLTABLE
                        (
                            '/td' PASSING A.tr_td
                            COLUMNS ID FOR ORDINALITY,
                            td VARCHAR2(4000 BYTE) PATH '.'
                        ) B
                            ON 1 = 1
                        --Header row
                        WHERE A.ID > 1
                        --More details column
                        AND B.ID < 4
                    )
                    PIVOT
                    (
                        MIN(TD)
                        FOR ID_1 IN
                        (
                            1 AS Language_ID,
                            2 AS Parent$Language_ID,
                            3 AS Name
                        )
                    )
                ) B
                    ON A.ID = B.ID
                WHERE UPPER
                (
                    SUBSTRB(A.ID, 1, 1)
                ) = UPPER(C.UnicodeCharacter)
                AND B.ID IS NULL
            );
            
            nDeleted := nDeleted + SQL%ROWCOUNT;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            /*--No more data to read from socket, XML in cursor Oracle bug
            FOR C IN
            (
                SELECT A.ID,
                A.Parent$S_ISO639_6_ID,
                A.Name,
                A.Comments
                FROM S_ISO639_6 A
                LEFT OUTER JOIN
                (
                    SELECT REPLACE(Language_ID,' ') AS ID
                    FROM
                    (
                        SELECT A.ID AS ID_0,
                        B.ID ID_1,
                        B.td
                        FROM XMLTABLE
                        (
                            '/table/tr' PASSING xXML
                            COLUMNS ID FOR ORDINALITY,
                            tr_td XMLTYPE PATH 'td'
                        ) A
                        --    ON 1 = 1
                        INNER JOIN XMLTABLE
                        (
                            '/td' PASSING A.tr_td
                            COLUMNS ID FOR ORDINALITY,
                            td VARCHAR2(4000 BYTE) PATH '.'
                        ) B
                            ON 1 = 1
                        --Header row
                        WHERE A.ID > 1
                        --More details column
                        AND B.ID < 4
                    )
                    PIVOT
                    (
                        MIN(TD)
                        FOR ID_1 IN
                        (
                            1 AS Language_ID,
                            2 AS Parent$Language_ID,
                            3 AS Name
                        )
                    )
                ) B
                    ON A.ID = B.ID
                WHERE UPPER
                (
                    SUBSTRB(A.ID, 1, 1)
                ) = UPPER(C.UnicodeCharacter)
                AND B.ID IS NULL
            ) LOOP
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'DELETE' || '</td>'
                || '<td>' || 'S_ISO639_6' || '</td>'
                || '<td>'
                || 'ID: ' || A.ID || CHR(10)
                || 'Parent$S_ISO639_6_ID: ' || A.Parent$S_ISO639_6_ID || CHR(10)
                || 'Name: ' || TEXT_TO_HTML(A.Name) || CHR(10)
                || 'Comments: ' || TEXT_TO_HTML(A.Comments)
                || '</td>';
                
                DELETE
                FROM S_ISO639_6
                WHERE ID = C.ID;
                
                nDeleted := nDeleted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END LOOP;*/
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'MERGE' || '</td>'
            || '<td>' || 'S_ISO639_6' || '</td>'
            || '<td>' || '' || '</td>';
            
            MERGE
            INTO S_ISO639_6 X
            USING
            (
                SELECT Language_ID AS ID,
                CASE
                    WHEN INSTRB(Parent$Language_IDs, ' | ') > 1 THEN SUBSTRB(Parent$Language_IDs, 1, INSTRB(Parent$Language_IDs, ' | ') -1)
                    ELSE Parent$Language_IDs
                END AS Parent$S_ISO639_6_ID,
                Names AS Name,
                CASE
                    WHEN INSTRB(Parent$Language_IDs, ' | ') > 1 THEN 'Additional Parent$S_ISO639_6_ID(s): ' || SUBSTRB(Parent$Language_IDs, INSTRB(Parent$Language_IDs, ' | ') + 3)
                    ELSE NULL
                END AS Comments
                FROM
                (
                    SELECT Language_ID,
                    LISTAGG(Parent$Language_ID, ' | ') WITHIN GROUP (ORDER BY ID_0) AS Parent$Language_IDs,
                    LISTAGG(Name, ' | ') WITHIN GROUP (ORDER BY ID_0) AS Names
                    FROM
                    (
                        SELECT REPLACE(Language_ID,' ') AS Language_ID,
                        REPLACE(Parent$Language_ID,' ') AS Parent$Language_ID,
                        REGEXP_REPLACE
                        (
                            TRIM(Name),
                            '[[:blank:]]{2,}',
                            ' '
                        ) AS Name,
                        ID_0
                        FROM
                        (
                            SELECT A.ID AS ID_0,
                            B.ID AS ID_1,
                            B.td
                            FROM
                            /*(
                                SELECT XMLTRANSFORM
                                (
                                    XMLPARSE
                                    (
                                        DOCUMENT REPLACE
                                        (
                                            UNESCAPE_REFERENCE_CLOB(cCLOB),
                                            '&',
                                            '&amp;'
                                        )
                                    ),
                                    (
                                        SELECT XML
                                        FROM XSLT
                                        WHERE Name = 'REMOVE_COMMENTS'
                                    )
                                ) AS xXML
                                FROM TMP_CLOB
                                WHERE ID = 3
                            ) XML
                            INNER JOIN */XMLTABLE
                            (
                                '/table/tr' PASSING /*XML.*/xXML
                                COLUMNS ID FOR ORDINALITY,
                                tr_td XMLTYPE PATH 'td'
                            ) A
                                --ON 1 = 1
                            INNER JOIN XMLTABLE
                            (
                                '/td' PASSING A.tr_td
                                COLUMNS ID FOR ORDINALITY,
                                td VARCHAR2(4000 BYTE) PATH '.'
                            ) B
                                ON 1 = 1
                            --Header row
                            WHERE A.ID > 1
                            --More details column
                            AND B.ID < 4
                        )
                        PIVOT
                        (
                            MIN(TD)
                            FOR ID_1 IN
                            (
                                1 AS Language_ID,
                                2 AS Parent$Language_ID,
                                3 AS Name
                            )
                        )
                        --Ignore all languages with more than four bytes as these are not ISO-conformant
                        WHERE LENGTHB
                        (
                            REPLACE(Language_ID, ' ')
                        ) <= 4
                        AND
                        (
                            LENGTHB
                            (
                                REPLACE(Parent$Language_ID, ' ')
                            ) <= 4
                            OR REPLACE(Parent$Language_ID, ' ') IS NULL
                        )
                    )
                    GROUP BY Language_ID
                )
                --
                MINUS
                --
                SELECT ID,
                Parent$S_ISO639_6_ID,
                Name,
                Comments
                FROM S_ISO639_6
                WHERE UPPER
                (
                    SUBSTRB(ID, 1, 1)
                ) = UPPER(C.UnicodeCharacter)
            ) Y
                ON (X.ID = Y.ID)
            WHEN MATCHED THEN UPDATE SET X.Parent$S_ISO639_6_ID = Y.Parent$S_ISO639_6_ID,
            X.Name = Y.Name
            WHERE COALESCE(X.Parent$S_ISO639_6_ID, '-1') <> COALESCE(Y.Parent$S_ISO639_6_ID, '-1')
            OR X.Name <> Y.Name
            WHEN NOT MATCHED THEN INSERT
            (
                ID,
                PARENT$S_ISO639_6_ID,
                NAME
            )
            VALUES
            (
                Y.ID,
                Y.Parent$S_ISO639_6_ID,
                Y.Name
            );
            
            nMerged := nMerged + SQL%ROWCOUNT;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP; --End loop around letters
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_ISO639_6')
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
            WHERE Table_Name IN ('S_ISO639_6')
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
                OWNNAME=>NULL,
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
    
    REFRESH_S_ISO639_6;
    
END;
/
*/