SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_UNIVERSALONTOLOGYCLASS
AS
    
    l_Table_Name USER_TABLES.Table_Name%TYPE := 'UNIVERSALONTOLOGYCLASS';
    
    --Email variables
    l_Email_Subject VARCHAR2(78 CHAR) := SUBSTRB(l_Table_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    l_Email_Body    CLOB              := EMPTY_CLOB();
    
    --Program variables
    l_Rows_Deleted     PLS_INTEGER := 0;
    l_Rows_Merged      PLS_INTEGER := 0;
    l_Timestamp_Format CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
    --Error variables
    HANDLED      EXCEPTION;
    l_Error_Text VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.Enable(NULL);
    
    BEGIN
        
        l_Email_Body := CHR(10)
        || '<html lang="en">' || CHR(10)
        || '<head>' || CHR(10)
        || '<title>' || TEXT_TO_HTML(l_Email_Subject) || '</title>' || CHR(10)
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
            SELECT 'https://haddenindustries.com/ontology/universal/reference-data/latest' AS URL FROM DUAL
            UNION ALL
            SELECT 'https://haddenindustries.com/ontology/universal/core/latest' AS URL FROM DUAL
            UNION ALL
            SELECT 'https://haddenindustries.com/ontology/universal/extended/latest' AS URL FROM DUAL
            /*UNION ALL
            SELECT 'https://haddenindustries.com/ontology/iso-iec/11179/-3/ed-3/v1' AS URL FROM DUAL*/
        ) LOOP
        
            l_Email_Body := l_Email_Body || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, l_Timestamp_Format) || '</td>'
            || '<td>' || 'MERGE' || '</td>'
            || '<td>' || l_Table_Name || '</td>'
            || '<td>' || C.URL || '</td>';
            
            MERGE
            INTO UNIVERSALONTOLOGYCLASS X
            USING
            (
                SELECT X.ID,
                X.About,
                X.Created,
                X.Creator,
                X.Description,
                X.Label,
                X.Title,
                X.Modified
                FROM
                (
                    SELECT ID,
                    About,
                    Created,
                    Creator,
                    Description,
                    Label,
                    Title,
                    Modified
                    FROM
                    (
                        SELECT UNCANONICALISE_UUID
                        (
                            SUBSTRB(IDENTIFIERS.Val, LENGTHB('urn:uuid:') + 1, 36)
                        ) AS ID,
                        A.About,
                        TO_DATE(A.Created, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS Created,
                        A.Creator,
                        DESCRIPTIONS.Val AS Description,
                        DESCRIPTIONS.Lang AS DescriptionLanguage,
                        RANK() OVER
                        (
                            PARTITION BY A.About
                            ORDER BY CASE
                                WHEN DESCRIPTIONS.Lang = 'en-gb' THEN CHR(0)
                                WHEN DESCRIPTIONS.Lang = 'en' THEN CHR(1)
                                ELSE DESCRIPTIONS.Lang
                            END
                        ) DescriptionLanguageRank,
                        COALESCE
                        (
                            A.Label,
                            SUBSTR
                            (
                                A.About,
                                INSTR(A.About, '/', -1) + 1
                            )   
                        ) AS Label,
                        TO_DATE(A.Modified, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS Modified,
                        COALESCE
                        (
                            TITLES.Val,
                            TRIM
                            (
                                REGEXP_REPLACE
                                (
                                    SUBSTR
                                    (
                                        A.About,
                                        INSTR(A.About, '/', -1) + 1
                                    ),
                                    '([A-Z])',
                                    ' \1'
                                )
                            )
                        ) AS Title,
                        TITLES.Lang AS TitleLanguage,
                        RANK() OVER
                        (
                            PARTITION BY A.About
                            ORDER BY CASE
                                WHEN TITLES.Lang = 'en-gb' THEN CHR(0)
                                WHEN TITLES.Lang = 'en' THEN CHR(1)
                                ELSE TITLES.Lang
                            END
                        ) TitleLanguageRank
                        FROM XMLTABLE
                        (
                            XMLNAMESPACES
                            (
                                DEFAULT 'http://standards.iso.org/iso-iec/11179/-3/ed-3/',
                                'https://haddenindustries.com/ontology/universal/reference-data/' AS "rd",
                                'https://haddenindustries.com/ontology/universal/core/' AS "uc",
                                'https://haddenindustries.com/ontology/universal/extended/' AS "ue",
                                'http://www.w3.org/1999/02/22-rdf-syntax-ns#' AS "rdf",
                                'http://www.w3.org/2000/01/rdf-schema#' AS "rdfs",
                                'http://www.w3.org/2002/07/owl#' AS "owl",
                                'http://purl.org/dc/elements/1.1/' AS "dc",
                                'http://purl.org/dc/terms/' AS "dcterms"
                            ),
                            '/rdf:RDF/owl:Class' PASSING XMLTYPE
                            (
                                URL_TO_BLOB(C.URL),
                                NLS_CHARSET_ID('AL32UTF8')
                            )
                            RETURNING SEQUENCE BY REF
                            COLUMNS About VARCHAR2(4000 BYTE) PATH '@rdf:about',
                            Created VARCHAR2(100 BYTE) PATH 'dcterms:created',
                            Creator VARCHAR2(100 BYTE) PATH 'dc:creator/@rdf:resource',
                            DescriptionsXML XMLTYPE PATH 'dcterms:description',
                            Label VARCHAR2(100 BYTE) PATH 'rdfs:label',
                            IdentifiersXML XMLTYPE PATH 'dcterms:identifier',
                            Modified VARCHAR2(100 BYTE) PATH 'dcterms:modified',
                            TitlesXML XMLTYPE PATH 'dcterms:title'
                        ) A
                        CROSS JOIN XMLTABLE
                        (
                            XMLNAMESPACES
                            (
                                DEFAULT 'http://purl.org/dc/terms/'
                            ),
                            '/description' PASSING A.DescriptionsXML
                            RETURNING SEQUENCE BY REF
                            COLUMNS Val VARCHAR2(4000 BYTE) PATH '.',
                            Lang CHAR(36 BYTE) PATH '@xml:lang'
                        ) DESCRIPTIONS
                        CROSS JOIN XMLTABLE
                        (
                            XMLNAMESPACES
                            (
                                DEFAULT 'http://purl.org/dc/terms/',
                                'http://www.w3.org/1999/02/22-rdf-syntax-ns#' AS "rdf"
                            ),
                            '/identifier' PASSING A.IdentifiersXML
                            RETURNING SEQUENCE BY REF
                            COLUMNS Val VARCHAR2(4000 BYTE) PATH '@rdf:resource'
                        ) IDENTIFIERS
                        CROSS JOIN XMLTABLE
                        (
                            XMLNAMESPACES
                            (
                                DEFAULT 'http://purl.org/dc/terms/'
                            ),
                            '/title' PASSING A.TitlesXML
                            RETURNING SEQUENCE BY REF
                            COLUMNS Val VARCHAR2(4000 BYTE) PATH '.',
                            Lang CHAR(36 BYTE) PATH '@xml:lang'
                        ) TITLES
                        WHERE IDENTIFIERS.Val LIKE 'urn:uuid:%'
                    )
                    WHERE DescriptionLanguageRank = 1
                    AND TitleLanguageRank = 1
                ) X
                LEFT OUTER JOIN UNIVERSALONTOLOGYCLASS Y
                    ON X.ID = Y.ID
                WHERE Y.ID IS NULL
                OR X.About != Y.About
                OR X.Created != Y.Created
                OR X.Creator != Y.Creator
                OR X.Description != Y.Description
                OR X.Label != Y.Label
                OR X.Title != Y.Title
                OR
                (
                    (
                        X.Modified IS NOT NULL AND Y.Modified IS NOT NULL
                        AND X.Modified != Y.Modified
                    )
                    OR
                    (X.Modified IS NOT NULL AND Y.Modified IS NULL)
                    OR
                    (X.Modified IS NULL AND Y.Modified IS NOT NULL)
                )
            ) Y
                ON (X.ID = Y.ID)
            WHEN MATCHED THEN UPDATE SET X.ABOUT = Y.ABOUT,
            X.CREATED = Y.CREATED,
            X.CREATOR = Y.CREATOR,
            X.DESCRIPTION = Y.DESCRIPTION,
            X.LABEL = Y.LABEL,
            X.TITLE = Y.TITLE,
            X.MODIFIED = Y.MODIFIED
            WHEN NOT MATCHED THEN INSERT
            (
                ID,
                ABOUT,
                CREATED,
                CREATOR,
                DESCRIPTION,
                LABEL,
                TITLE,
                MODIFIED
            )
            VALUES
            (
                Y.ID,
                Y.ABOUT,
                Y.CREATED,
                Y.CREATOR,
                Y.DESCRIPTION,
                Y.LABEL,
                Y.TITLE,
                Y.MODIFIED
            );
            
            l_Rows_Merged := l_Rows_Merged + SQL%ROWCOUNT;
            
            l_Email_Body := l_Email_Body || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP; 
        
        
        l_Email_Body := l_Email_Body || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, l_Timestamp_Format) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'TABLELOOKUP' || '</td>'
        || '<td>' || l_Table_Name || '</td>';
        
        --TOUCH(l_Table_Name);
        NULL;
        
        l_Email_Body := l_Email_Body || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        l_Email_Body := l_Email_Body || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, l_Timestamp_Format) || '</td>'
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        l_Email_Body := l_Email_Body || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        IF l_Rows_Merged > 0 THEN
        
            l_Email_Body := l_Email_Body || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, l_Timestamp_Format) || '</td>'
            || '<td>' || 'GATHER STATS' || '</td>'
            || '<td>' || l_Table_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_STATS.Gather_Table_Stats
            (
                OWNNAME          => NULL,
                TABNAME          => l_Table_Name,
                METHOD_OPT       => 'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE          => TRUE,
                ESTIMATE_PERCENT => 100
            );
            
            l_Email_Body := l_Email_Body || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
        
        END IF;
        
        
        l_Email_Body := l_Email_Body || CHR(10)
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
                    XMLPARSE(DOCUMENT l_Email_Body)
                ) AS CLOB INDENT SIZE = 2
            ),
            '&apos;',
            '&#39;'
        )
        INTO l_Email_Body
        FROM DUAL;
        
    EXCEPTION
    WHEN HANDLED THEN
        
        l_Email_Body := l_Email_Body || CHR(10)
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
                    XMLPARSE(DOCUMENT l_Email_Body)
                ) AS CLOB INDENT SIZE = 2
            ),
            '&apos;',
            '&#39;'
        )
        INTO l_Email_Body
        FROM DUAL;
        
    WHEN OTHERS THEN
        
        ROLLBACK;
        
        l_Error_Text := SUBSTRB(SQLErrM, 1, 255);
        
        l_Email_Body := l_Email_Body || ' (' || l_Error_Text || ')';
        
        DBMS_OUTPUT.Put_Line
        (
            DBMS_LOB.Substr(l_Email_Body)
        );
        
    END;
    
    BEGIN
        
        EMAIL.Send
        (
            Subject => l_Email_Subject,
            Body    => l_Email_Body
        );
        
    EXCEPTION
    WHEN OTHERS THEN
        
        l_Error_Text := SUBSTRB(SQLErrM, 1, 248);
        
        DBMS_OUTPUT.Put_Line('EMAIL: ' || l_Error_Text);
        
    END;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_UNIVERSALONTOLOGYCLASS;
    
END;
/
*/