SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_NUMBERINGAGENCY
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'NUMBERINGAGENCY';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    bExists BOOLEAN := FALSE;
    nRowsInserted PLS_INTEGER := 0;
    nRowsUpdated PLS_INTEGER := 0;
    nRowsDeleted PLS_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM NUMBERINGAGENCY
        WHERE (Country_ID, National) IN
        (
            WITH NSIN AS
            (
                SELECT 'GBR' AS Country_ID,'Stock Exchange Daily Official List' NSINName, 'SEDOL' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'IRL' AS Country_ID, 'Stock Exchange Daily Official List' NSINName, 'SEDOL' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'USA' AS Country_ID, 'Committee on Uniform Security Identification Procedures' AS NSINName, 'CUSIP' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'FRA' AS Country_ID, 'Société Interprofessionnelle pour la Compensation des Valeurs Mobilières' AS NSINName, 'SICOVAM' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'DEU' AS Country_ID, 'Wertpapierkennnummer' AS NSINName, 'WKN' NSINAcronym, 'http://www.pruefziffernberechnung.de/I/ISIN.shtml' AS Comments FROM DUAL
                UNION ALL
                SELECT 'CHE' AS Country_ID, 'VALOR number' AS NSINName, 'VALOR' AS NSINAcronym, '' AS Comments FROM DUAL
            ),
            --
            S_NNA_UNIQUE AS
            (
                SELECT Country_Alpha2,
                'T' AS National,
                LISTAGG(Name, '; ') WITHIN GROUP (ORDER BY Name) AS Name,
                LISTAGG(ANNAMembership, '; ') WITHIN GROUP (ORDER BY ANNAMembership) AS ANNAMembership,
                NULL AS Comments
                FROM S_NUMBERINGAGENCYNATIONAL
                GROUP BY Country_Alpha2
                --
                UNION ALL
                --
                SELECT Country_Alpha2,
                'F' AS National,
                Name,
                NULL AS ANNAMembership,
                Comments
                FROM S_NUMBERINGAGENCYSUBSTITUTE
            )
            --
            SELECT Country_ID,
            National
            FROM NUMBERINGAGENCY
            WHERE (Country_ID, National) NOT IN
            (
                SELECT /*+ HASH_AJ */
                Country_ID,
                National
                FROM
                (
                    SELECT B.ID AS Country_ID,
                    A.National,
                    COALESCE(A.Name, 'Unknown') AS Name,
                    A.ANNAMembership,
                    CASE A.Name
                        WHEN 'CUSIP Global Services' THEN 'Committee on Uniform Security Identification Procedures'
                        WHEN 'SIX Financial Information Ltd' THEN 'VALOR number'
                        WHEN 'WM Datenservice' THEN 'Wertpapierkennnummer'
                        ELSE C.NSINName
                    END AS NSINName,
                    CASE A.Name
                        WHEN 'CUSIP Global Services' THEN 'CUSIP'
                        WHEN 'SIX Financial Information Ltd' THEN 'VALOR'
                        WHEN 'WM Datenservice' THEN 'WKN'
                        ELSE C.NSINAcronym
                    END AS NSINAcronym,
                    COALESCE(C.Comments, A.Comments) AS Comments
                    FROM S_NNA_UNIQUE A
                    INNER JOIN COUNTRY B
                        ON A.Country_Alpha2 = B.Alpha2
                            AND TRUNC(SYSDATE_UTC) BETWEEN COALESCE(B.DateStart, TO_DATE('0001-01-01', 'YYYY-MM-DD')) AND COALESCE(B.DateEnd, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
                    LEFT OUTER JOIN NSIN C
                        ON B.ID = C.Country_ID
                )
                WHERE Country_ID IS NOT NULL
                AND National IS NOT NULL
            )
        );
        
        nRowsDeleted := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(nRowsDeleted) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            WITH NSIN AS
            (
                SELECT 'GBR' AS Country_ID,'Stock Exchange Daily Official List' NSINName, 'SEDOL' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'IRL' AS Country_ID, 'Stock Exchange Daily Official List' NSINName, 'SEDOL' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'USA' AS Country_ID, 'Committee on Uniform Security Identification Procedures' AS NSINName, 'CUSIP' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'FRA' AS Country_ID, 'Société Interprofessionnelle pour la Compensation des Valeurs Mobilières' AS NSINName, 'SICOVAM' AS NSINAcronym, '' AS Comments FROM DUAL
                UNION ALL
                SELECT 'DEU' AS Country_ID, 'Wertpapierkennnummer' AS NSINName, 'WKN' NSINAcronym, 'http://www.pruefziffernberechnung.de/I/ISIN.shtml' AS Comments FROM DUAL
                UNION ALL
                SELECT 'CHE' AS Country_ID, 'VALOR number' AS NSINName, 'VALOR' AS NSINAcronym, '' AS Comments FROM DUAL
            ),
            --
            S_NNA_UNIQUE AS
            (
                SELECT Country_Alpha2,
                'T' AS National,
                LISTAGG(Name, '; ') WITHIN GROUP (ORDER BY Name) AS Name,
                LISTAGG(ANNAMembership, '; ') WITHIN GROUP (ORDER BY Name) AS ANNAMembership,
                NULL AS Comments
                FROM S_NUMBERINGAGENCYNATIONAL
                GROUP BY Country_Alpha2
                --
                UNION ALL
                --
                SELECT Country_Alpha2,
                'F' AS National,
                Name,
                NULL AS ANNAMembership,
                Comments
                FROM S_NUMBERINGAGENCYSUBSTITUTE
            )
            --
            SELECT B.ID AS Country_ID,
            A.National,
            COALESCE(A.Name, 'Unknown') AS Name,
            A.ANNAMembership,
            CASE A.Name
                WHEN 'CUSIP Global Services' THEN 'Committee on Uniform Security Identification Procedures'
                WHEN 'SIX Financial Information Ltd' THEN 'VALOR number'
                WHEN 'WM Datenservice' THEN 'Wertpapierkennnummer'
                ELSE C.NSINName
            END AS NSINName,
            CASE A.Name
                WHEN 'CUSIP Global Services' THEN 'CUSIP'
                WHEN 'SIX Financial Information Ltd' THEN 'VALOR'
                WHEN 'WM Datenservice' THEN 'WKN'
                ELSE C.NSINAcronym
            END AS NSINAcronym,
            COALESCE(C.Comments, A.Comments) AS Comments
            FROM S_NNA_UNIQUE A
            INNER JOIN COUNTRY B
                ON A.Country_Alpha2 = B.Alpha2
                    AND TRUNC(SYSDATE_UTC) BETWEEN COALESCE(B.DateStart, TO_DATE('0001-01-01', 'YYYY-MM-DD')) AND COALESCE(B.DateEnd, TO_DATE('9999-12-31', 'YYYY-MM-DD'))
            LEFT OUTER JOIN NSIN C
                ON B.ID = C.Country_ID
            --
            MINUS
            --
            SELECT Country_ID,
            National,
            Name,
            ANNAMembership,
            NSINName,
            NSINAcronym,
            Comments
            FROM NUMBERINGAGENCY
            ORDER BY Country_ID,
            National
        ) LOOP
            
            
            bExists := FALSE;
            
            
            FOR D IN
            (
                SELECT Country_ID,
                National,
                Name,
                ANNAMembership,
                NSINName,
                NSINAcronym,
                Comments
                FROM NUMBERINGAGENCY
                WHERE Country_ID = C.Country_ID
                AND National = C.National
            ) LOOP
                
                
                bExists := TRUE;


                IF C.Name != D.Name THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Name' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET Name = C.Name
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Name || '=>' || C.Name || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.ANNAMembership, CHR(0)) != COALESCE(D.ANNAMembership, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.ANNAMembership' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET ANNAMembership = C.ANNAMembership
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.ANNAMembership || '=>' || C.ANNAMembership || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NSINAcronym, CHR(0)) != COALESCE(D.NSINAcronym, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.NSINAcronym' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET NSINAcronym = C.NSINAcronym
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NSINAcronym || '=>' || C.NSINAcronym || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NSINName, CHR(0)) != COALESCE(D.NSINName, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.NSINName' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET NSINName = C.NSINName
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NSINName || '=>' || C.NSINName || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                /*IF COALESCE(C.NSINRegEx, CHR(0)) != COALESCE(D.NSINRegEx, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.NSINRegEx' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET NSINRegEx = C.NSINRegEx
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NSINRegEx || '=>' || C.NSINRegEx || ')' || '</td>'
                    || '</tr>';
                    
                END IF;*/
                
                
                IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Comments' || '</td>'
                    || '<td>' || C.Country_ID || ' ' || C.National || '</td>';
                    
                    UPDATE
                    NUMBERINGAGENCY
                    SET Comments = C.Comments
                    WHERE Country_ID = C.Country_ID
                    AND National = C.National;
                    
                    nRowsUpdated := nRowsUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Comments || '=>' || C.Comments || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
            
            END LOOP;
            
            
            IF NOT bExists THEN
                    
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || vTable_Name || '</td>'
                || '<td>' || TEXT_TO_HTML(C.Country_ID) || ','
                || TEXT_TO_HTML(C.National) || ','
                || TEXT_TO_HTML(C.Name) || ','
                || TEXT_TO_HTML(C.ANNAMembership) || ','
                || TEXT_TO_HTML(C.NSINName) || ','
                || TEXT_TO_HTML(C.NSINAcronym) || ','
                || TEXT_TO_HTML(C.Comments) || '</td>';
                
                INSERT
                INTO NUMBERINGAGENCY
                (
                    COUNTRY_ID,
                    NATIONAL,
                    NAME,
                    ANNAMEMBERSHIP,
                    NSINACRONYM,
                    NSINNAME,
                    --NSINREGEX,
                    COMMENTS
                )
                VALUES
                (
                    C.COUNTRY_ID,
                    C.NATIONAL,
                    C.NAME,
                    C.ANNAMEMBERSHIP,
                    C.NSINACRONYM,
                    C.NSINNAME,
                    --C.NSINREGEX,
                    C.COMMENTS
                );
                
                nRowsInserted := nRowsInserted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
        
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
        
        
        IF ((nRowsDeleted + nRowsInserted + nRowsUpdated) > 0) THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || vTable_Name || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table(vTable_Name, vGoogleOutput);
                
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
            DBMS_LOB.SUBSTR(vMsg, 4000)
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
    
    REFRESH_NUMBERINGAGENCY;
    
END;
/

--header rows
SELECT B.*
FROM
(
    SELECT XMLTRANSFORM
    (
        XMLTYPE(Data),
        (
            SELECT XML
            FROM XSLT
            WHERE Name = 'REMOVE_COMMENTS'
        )
    ) AS xXML
    FROM LATEST$INBOUND X
    WHERE X.TableLookup_Name = 'ROOTZONEDATABASE'
) XML
INNER JOIN XMLTABLE
(
    '/table' PASSING XML.xXML
    COLUMNS thead_tr_th XMLTYPE PATH 'thead/tr/th'
) A
    ON 1 = 1
INNER JOIN XMLTABLE
(
    '/th' PASSING A.thead_tr_th
    COLUMNS ID FOR ORDINALITY,
    th VARCHAR2(4000 BYTE) PATH '.'
) B
    ON 1 = 1;
*/