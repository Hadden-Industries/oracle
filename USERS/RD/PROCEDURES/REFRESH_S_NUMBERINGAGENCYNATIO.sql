SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_S_NUMBERINGAGENCYNATIO(gRefreshEvenWhenSameData INTEGER DEFAULT 0)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'S_NUMBERINGAGENCYNATIONAL';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vURL VARCHAR2(4000 BYTE) := Get_Table_Refresh_Source_URL(vTable_Name);
    cTmp CLOB := EMPTY_CLOB();
    nErrors PLS_INTEGER := 0;
    nDeletes PLS_INTEGER := 0;
    
    --Document formatting variable
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    
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
        
        BEGIN
            
            SAVE_DATA_FROM_URL
            (
                gURL=>vURL,
                gTableLookup_Name=>vTable_Name
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL);
        
        nDeletes := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF nDeletes > 0 AND gRefreshEvenWhenSameData = 0 THEN --Nothing to update, so exit
            
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
            
            
            RAISE HANDLED;
            
            
        END IF;
        
        
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
            SELECT Offset,
            Position_End - Offset + LENGTH('</table>') AS Amount,
            Data
            FROM
            (
                SELECT DBMS_LOB.INSTR(Data, '<table', 1, 1) AS Offset, --First table
                INSTR(Data, '</table>', -1, 1) AS Position_End, --End of first table
                Data
                FROM LATEST$INBOUND X
                WHERE X.TableLookup_Name = vTable_Name
                AND X.URL = vURL
            )
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CREATE' || '</td>'
            || '<td>' || 'Table CLOB' || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_LOB.CreateTemporary(cTmp, TRUE);
            
            DBMS_LOB.Copy(cTmp, C.Data, C.Amount, 1, C.Offset);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            --debugging
            /*INSERT INTO TMP VALUES(cTmp);
            
            COMMIT;
            
            RAISE HANDLED;*/
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'CHECK' || '</td>'
        || '<td>' || 'Duplicates in delta' || '</td>'
        || '<td>' || '' || '</td>';
        
        WITH S_DELTA AS
        (
            SELECT /*+ MATERIALIZE */
            Country_Name,
            Name,
            Country_Alpha2,
            ANNAMembership
            FROM
            (
                SELECT A.ID,
                C.ID AS TR_ID,
                COALESCE
                (
                    SINGLE_LINE(C.TD_A),
                    SINGLE_LINE(C.TD)
                ) AS TD
                FROM
                (
                    SELECT XMLTRANSFORM
                    (
                        XMLPARSE
                        (
                            DOCUMENT REPLACE
                            (
                                REPLACE
                                (
                                    UNESCAPE_REFERENCE_CLOB(cTmp),
                                    '&',
                                    '&amp;'
                                ),
                                '<br>',
                                '<br />'
                            )
                        ),
                        (
                            SELECT XML
                            FROM XSLT
                            WHERE Name = 'REMOVE_COMMENTS'
                        )
                    ) AS xXML
                    FROM DUAL
                ) XML
                INNER JOIN XMLTABLE
                (
                    '/table/tbody/tr' PASSING XML.xXML
                    COLUMNS ID FOR ORDINALITY,
                    tr XMLTYPE PATH '.'
                ) A
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/tr' PASSING A.tr
                    COLUMNS ID FOR ORDINALITY,
                    td XMLTYPE PATH 'td'
                ) B
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/td' PASSING B.td
                    COLUMNS ID FOR ORDINALITY,
                    td_a VARCHAR2(4000 BYTE) PATH './a',
                    td VARCHAR2(4000 BYTE) PATH '.'
                ) C
                    ON 1 = 1
                WHERE A.ID > 1
            )
            PIVOT
            (
                MIN(TD) FOR TR_ID IN
                (
                    1 AS Country_Name,
                    2 AS Name,
                    3 AS Country_Alpha2,
                    4 AS ANNAMembership
                )
            )
            --
            MINUS
            --
            SELECT Country_Name,
            Name,
            Country_Alpha2,
            ANNAMembership
            FROM S_NUMBERINGAGENCYNATIONAL
        )
        --
        SELECT COUNT(*)
        INTO nErrors
        FROM S_DELTA
        WHERE Country_Alpha2 IN
        (
            SELECT Country_Alpha2
            FROM S_NUMBERINGAGENCYNATIONAL
            GROUP BY Country_Alpha2
            HAVING COUNT(*) > 1
        )
        --There are two entries for XS, Clearstream and Euroclear
        AND Country_Alpha2 != 'XS';
        
        vMsg := vMsg || '<td>' || TO_CHAR(nErrors) || '</td>'
        || '</tr>';
        
        
        IF nErrors > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM S_NUMBERINGAGENCYNATIONAL
        WHERE Country_Alpha2 IS NOT NULL
        AND Country_Alpha2 NOT IN
        (
            WITH S_NEW AS
            (
                SELECT /*+ MATERIALIZE */
                Country_Name,
                Name,
                Country_Alpha2,
                ANNAMembership
                FROM
                (
                    SELECT A.ID,
                    C.ID AS TR_ID,
                    COALESCE
                    (
                        SINGLE_LINE(C.TD_A),
                        SINGLE_LINE(C.TD)
                    ) AS TD
                    FROM
                    (
                        SELECT XMLTRANSFORM
                        (
                            XMLPARSE
                            (
                                DOCUMENT REPLACE
                                (
                                    REPLACE
                                    (
                                        UNESCAPE_REFERENCE_CLOB(cTmp),
                                        '&',
                                        '&amp;'
                                    ),
                                    '<br>',
                                    '<br />'
                                )
                            ),
                            (
                                SELECT XML
                                FROM XSLT
                                WHERE Name = 'REMOVE_COMMENTS'
                            )
                        ) AS xXML
                        FROM DUAL
                    ) XML
                    INNER JOIN XMLTABLE
                    (
                        '/table/tbody/tr' PASSING XML.xXML
                        COLUMNS ID FOR ORDINALITY,
                        tr XMLTYPE PATH '.'
                    ) A
                        ON 1 = 1
                    INNER JOIN XMLTABLE
                    (
                        '/tr' PASSING A.tr
                        COLUMNS ID FOR ORDINALITY,
                        td XMLTYPE PATH 'td'
                    ) B
                        ON 1 = 1
                    INNER JOIN XMLTABLE
                    (
                        '/td' PASSING B.td
                        COLUMNS ID FOR ORDINALITY,
                        td_a VARCHAR2(4000 BYTE) PATH './a',
                        td VARCHAR2(4000 BYTE) PATH '.'
                    ) C
                        ON 1 = 1
                    WHERE A.ID > 1
                )
                PIVOT
                (
                    MIN(TD) FOR TR_ID IN
                    (
                        1 AS Country_Name,
                        2 AS Name,
                        3 AS Country_Alpha2,
                        4 AS ANNAMembership
                    )
                )
            )
            --
            SELECT Country_Alpha2
            FROM S_NEW
            WHERE Country_Alpha2 IS NOT NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO S_NUMBERINGAGENCYNATIONAL X
        USING
        (
            SELECT Country_Name,
            Name,
            Country_Alpha2,
            ANNAMembership
            FROM
            (
                SELECT A.ID,
                C.ID AS TR_ID,
                COALESCE
                (
                    SINGLE_LINE(C.TD_A),
                    SINGLE_LINE(C.TD)
                ) AS TD
                FROM
                (
                    SELECT XMLTRANSFORM
                    (
                        XMLPARSE
                        (
                            DOCUMENT REPLACE
                            (
                                REPLACE
                                (
                                    UNESCAPE_REFERENCE_CLOB(cTmp),
                                    '&',
                                    '&amp;'
                                ),
                                '<br>',
                                '<br />'
                            )
                        ),
                        (
                            SELECT XML
                            FROM XSLT
                            WHERE Name = 'REMOVE_COMMENTS'
                        )
                    ) AS xXML
                    FROM DUAL
                ) XML
                INNER JOIN XMLTABLE
                (
                    '/table/tbody/tr' PASSING XML.xXML
                    COLUMNS ID FOR ORDINALITY,
                    tr XMLTYPE PATH '.'
                ) A
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/tr' PASSING A.tr
                    COLUMNS ID FOR ORDINALITY,
                    td XMLTYPE PATH 'td'
                ) B
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/td' PASSING B.td
                    COLUMNS ID FOR ORDINALITY,
                    td_a VARCHAR2(4000 BYTE) PATH './a',
                    td VARCHAR2(4000 BYTE) PATH '.'
                ) C
                    ON 1 = 1
                WHERE A.ID > 1
            )
            PIVOT
            (
                MIN(TD) FOR TR_ID IN
                (
                    1 AS Country_Name,
                    2 AS Name,
                    3 AS Country_Alpha2,
                    4 AS ANNAMembership
                )
            )
            WHERE Country_Alpha2 IS NOT NULL
            --
            MINUS
            --
            SELECT Country_Name,
            Name,
            Country_Alpha2,
            ANNAMembership
            FROM S_NUMBERINGAGENCYNATIONAL
        ) Y
            ON (X.Country_Alpha2 = Y.Country_Alpha2
                    AND X.Country_Name = Y.Country_Name)
        WHEN MATCHED THEN UPDATE SET X.Name = Y.Name,
        X.ANNAMembership = Y.ANNAMembership
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_NAME,
            NAME,
            COUNTRY_ALPHA2,
            ANNAMEMBERSHIP
        )
        VALUES
        (
            Y.Country_Name,
            Y.Name,
            Y.Country_Alpha2,
            Y.ANNAMembership
        );
        
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
            sender=>vSender,
            recipient=>vRecipient,
            cc=>vCC,
            bcc=>vBCC,
            subject=>vSubject,
            msg=>vMsg,
            attachments=>NULL
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

    REFRESH_S_NUMBERINGAGENCYNATIO(1);

END;
/
*/