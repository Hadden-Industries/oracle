SET DEFINE OFF;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRYSUBDIV
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRYSUBDIV ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    bExists BOOLEAN := FALSE;
    nInserted SIMPLE_INTEGER := 0;
    nUpdated SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
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
        
        --Oracle can't compile the staging table query when it is in the FOR loop, so need to have a physical table instead /sigh
        DELETE
        FROM S_COUNTRYSUBDIV;
        
        
        INSERT
        INTO S_COUNTRYSUBDIV
        (
            COUNTRY_ID,
            CODE,
            LANGUAGE_ID,
            ROMANISATIONSYSTEMNAME,
            PARENT$COUNTRYSUBDIV_CODE,
            NAME,
            SORTORDERCOUNTRY,
            TYPE
        )
        --
        WITH S_COUNTRY AS
        (
            SELECT ID AS Country_ID,
            'https://www.iso.org/obp/ui/#iso:code:3166:' || Alpha2 AS URL
            FROM COUNTRY AS OF PERIOD FOR VALID_TIME SYSDATE
        ),
        --
        XML AS
        (
            SELECT Country_ID,
            XMLPARSE
            (
                DOCUMENT SUBSTR
                (
                    Data,
                    Offset,
                    Position_End - Offset + LENGTH('</table>')
                )
            ) AS xXML
            FROM
            (
                SELECT B.Country_ID,
                DBMS_LOB.INSTR
                (
                    A.Data,
                    '<table>',
                    DBMS_LOB.INSTR(A.Data, '<div id="country-subdivisions">', 1, 1),
                    1
                ) AS Offset,
                DBMS_LOB.INSTR
                (
                    A.Data,
                    '</table>',
                    DBMS_LOB.INSTR(A.Data, '<div id="country-subdivisions">', 1, 1),
                    1
                ) AS Position_End,
                Data
                FROM LATEST$INBOUND A
                INNER JOIN S_COUNTRY B
                    ON A.URL = B.URL
            )
        )
        --
        SELECT Country_ID,
        SUBSTRB
        (
            CountrySubdivCode,
            INSTRB(CountrySubdivCode, '-') + 1
        ) AS Code,
        Language_ID,
        RomanisationSystemName,
        SUBSTRB
        (
            Parent$CountrySubdiv_Code,
            INSTRB(Parent$CountrySubdiv_Code, '-') + 1
        ) AS Parent$CountrySubdiv_Code,
        NameOfficial AS Name,
        SortOrderCountry,
        --Capitalise first letter of the type
        UPPER
        (
            SUBSTR(CountrySubdivType, 1, 1)
        )
        || SUBSTR(CountrySubdivType, 2) AS Type
        FROM
        (
            SELECT ID AS SortOrderCountry,
            Country_ID,
            SINGLE_LINE(CountrySubdivType) AS CountrySubdivType,
            REPLACE
            (
                SINGLE_LINE(CountrySubdivCode),
                '*'
            ) AS CountrySubdivCode,
            SINGLE_LINE(NameOfficial) AS NameOfficial,
            CASE
                WHEN Country_ID = 'ZAF' AND SINGLE_LINE(LanguageID) IS NULL THEN 'nso'
                ELSE MATCH_TO_LANGUAGE
                (
                    SINGLE_LINE(LanguageID)
                )
            END AS Language_ID,
            SINGLE_LINE(RomanisationSystemName) AS RomanisationSystemName,
            SINGLE_LINE(Parent$CountrySubdiv_Code) AS Parent$CountrySubdiv_Code
            FROM
            (
                SELECT XML.Country_ID,
                A.ID,
                B.ID_1,
                table_tbody_tr_td
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
                    1 AS CountrySubdivType,
                    2 AS CountrySubdivCode,
                    3 AS NameOfficial,
                    4 AS LanguageID,
                    5 AS RomanisationSystemName,
                    6 AS Parent$CountrySubdiv_Code
                )
            )
        );
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_COUNTRYSUBDIV')
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
        
        --To be deleted
        FOR C IN
        (
            WITH STAGING AS
            (
                SELECT Country_ID,
                Code
                FROM
                (
                    SELECT A.Country_ID,
                    A.Code,
                    ROW_NUMBER() OVER
                    (
                        PARTITION BY A.Country_ID, A.Code
                        ORDER BY CASE
                            WHEN A.Language_ID = 'eng' THEN 0
                            ELSE COALESCE(B.Rank, 1000000)
                        END
                    ) AS RN
                    FROM S_COUNTRYSUBDIV A
                    LEFT OUTER JOIN COUNTRY#LANGUAGE B
                        ON A.Country_ID = B.Country_ID
                                AND A.Language_ID = B.Language_ID
                )
                WHERE RN = 1
            )
            --
            SELECT ID,
            Country_ID,
            Code,
            Name
            FROM COUNTRYSUBDIV AS OF PERIOD FOR VALID_TIME SYSDATE
            WHERE (Country_ID, Code) NOT IN
            (
                SELECT Country_ID,
                Code
                FROM STAGING
            )
            ORDER BY ID
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'UPDATE' || '</td>'
            || '<td>' || 'COUNTRYSUBDIV.DateTransactionEnd' || '</td>'
            || '<td>' || C.Country_ID || ', ' || C.Code || '(' || C.ID || ') : ' || TEXT_TO_HTML(C.Name) || '</td>';
            
            UPDATE
            COUNTRYSUBDIV
            SET DateTransactionEnd = SYSDATE
            WHERE Country_ID = C.Country_ID
            AND Code = C.Code;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        FOR C IN
        (
            --the linked country code may be in a language other than English e.g. China's Hong Kong
            WITH S_PARENT AS
            (
                SELECT A.Country_ID,
                A.Code,
                MAX(B.ID) AS ISO3166P1$Country_ID
                FROM S_COUNTRYSUBDIV A
                INNER JOIN COUNTRY AS OF PERIOD FOR VALID_TIME SYSDATE B
                    ON CASE
                                WHEN A.Name LIKE '% (see also separate country code entry under %' THEN SUBSTRB
                                (
                                    A.Name,
                                    INSTRB(A.Name, ' (see also separate country code entry under ') + LENGTHB(' (see also separate country code entry under '),
                                    2
                                )
                                WHEN A.Country_ID = 'FIN' AND Code = '01' THEN 'AX'
                                ELSE NULL
                            END = B.Alpha2
                GROUP BY A.Country_ID,
                A.Code
            )
            --
            SELECT Country_ID,
            Code,
            Parent$CountrySubdiv_Code,
            ISO3166P1$Country_ID,
            IsNameOfficial,
            CASE
                WHEN INSTR(Name, '[') > 0 THEN 
                TRIM
                (
                    TRAILING ' '
                    FROM SUBSTR
                    (
                        Name,
                        1,
                        INSTR(Name, '[') - 1
                    )
                )
                ELSE Name
            END AS Name,
            Type,
            CASE
                WHEN INSTR(Name, '[') > 0 THEN 
                TRIM
                (
                    BOTH ' '
                    FROM SUBSTR
                    (
                        Name,
                        INSTR(Name, '[') + 1,
                        INSTR(Name, ']') - INSTR(Name, '[') - 1
                    )
                )
                WHEN Country_ID = 'GBR' AND Code = 'GBN' THEN 'England, Scotland, and Wales'
                WHEN Country_ID = 'GBR' AND Code = 'UKM' THEN 'England, Northern Ireland, Scotland, and Wales'
                ELSE NULL
            END AS Comments
            FROM
            (
                SELECT A.Country_ID,
                A.Code,
                A.Parent$CountrySubdiv_Code,
                C.ISO3166P1$Country_ID,
                CASE
                    WHEN A.Language_ID = 'eng' AND TO_ASCII(A.Name) = A.Name THEN 'T'
                    ELSE 'F'
                END AS IsNameOfficial,
                TRIM
                (
                    --for cases such as 'Aerodrom †'
                    BOTH ' '
                    FROM TO_ASCII
                    (
                        REPLACE
                        (
                            CASE
                                WHEN A.Name LIKE '% (see also separate country code entry under %' THEN SUBSTRB
                                (
                                    A.Name,
                                    1,
                                    INSTRB(A.Name, ' (see also separate country code entry under ') - 1
                                )
                                ELSE A.Name
                            END,
                            '*'
                        )
                    )
                ) AS Name,
                Type,
                ROW_NUMBER() OVER
                (
                    PARTITION BY A.Country_ID, A.Code
                    ORDER BY CASE
                        WHEN A.Language_ID = 'eng' THEN 0
                        ELSE COALESCE(B.Rank, 1000000)
                    END,
                    CASE
                        --Prioritise the latest Romanisation system
                        WHEN RomanisationSystemYear BETWEEN 1900 AND EXTRACT(YEAR FROM SYSDATE) THEN RomanisationSystemYear
                        ELSE NULL
                    END DESC,
                    A.RomanisationSystemName
                ) AS RN
                FROM
                (
                    SELECT Country_ID,
                    Code,
                    Language_ID,
                    RomanisationSystemName,
                    Parent$CountrySubdiv_Code,
                    Name,
                    SortOrderCountry,
                    Type,
                    CASE
                        WHEN RomanisationSystemName = 'BGN/PCGN 2009 romanization system based on Georgian national romanization 2002' THEN 2009
                        WHEN RomanisationSystemName = 'ISO/TR 11941' THEN 1996
                        WHEN RomanisationSystemName = 'KPS 11080:2002' THEN 2002
                        WHEN REGEXP_INSTR(RomanisationSystemName, '[[:digit:]]{4}') >0 THEN COALESCE
                        (
                            TO_NUMBER
                            (
                                --Second occurence of a four-digit year to handle revisions e.g. BGN/PCGN 1968, revised 2006
                                REGEXP_SUBSTR(RomanisationSystemName, '[[:digit:]]{4}', 1, 2)
                            ),
                            TO_NUMBER
                            (
                                REGEXP_SUBSTR(RomanisationSystemName, '[[:digit:]]{4}')
                            )
                        )
                        ELSE NULL 
                    END AS RomanisationSystemYear
                    FROM S_COUNTRYSUBDIV
                ) A
                LEFT OUTER JOIN COUNTRY#LANGUAGE B
                    ON A.Country_ID = B.Country_ID
                            AND A.Language_ID = B.Language_ID
                LEFT OUTER JOIN S_PARENT C
                    ON A.Country_ID = C.Country_ID
                            AND A.Code = C.Code
            )
            WHERE RN = 1
            ORDER BY Country_ID,
            Code
        ) LOOP
            
            bExists := FALSE;
            
            FOR D IN
            (
                SELECT Country_ID,
                Code,
                Parent$CountrySubdiv_Code,
                ISO3166P1$Country_ID,
                --ID,
                IsNameOfficial,
                IsNameOverride,
                Name,
                --SortOrder,
                Type,
                /*UUID,
                DateEnd,
                DateStart,
                DateTransactionEnd,
                DateTransactionStart,
                Geometry,*/
                Comments
                FROM COUNTRYSUBDIV
                WHERE Country_ID = C.Country_ID
                AND Code = C.Code
            ) LOOP
                
                bExists := TRUE;
                
                
                IF
                (
                    COALESCE(C.Parent$CountrySubdiv_Code, CHR(0)) <> COALESCE(D.Parent$CountrySubdiv_Code, CHR(0))
                    --Lithuanian parent country subdivision information missing from the ISO website
                    AND C.Country_ID NOT IN
                    (
                        'LTU'
                    )
                ) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.Parent$CountrySubdiv_Code' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET Parent$CountrySubdiv_Code = C.Parent$CountrySubdiv_Code
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Parent$CountrySubdiv_Code || '=>' || C.Parent$CountrySubdiv_Code || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.ISO3166P1$Country_ID, CHR(0)) <> COALESCE(D.ISO3166P1$Country_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.ISO3166P1$Country_ID' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET ISO3166P1$Country_ID = C.ISO3166P1$Country_ID
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.ISO3166P1$Country_ID || '=>' || C.ISO3166P1$Country_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.IsNameOfficial <> D.IsNameOfficial THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.IsNameOfficial' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET IsNameOfficial = C.IsNameOfficial
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.IsNameOfficial || '=>' || C.IsNameOfficial || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF CASE C.IsNameOfficial
                    WHEN 'T' THEN 'F'
                END <> D.IsNameOverride THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.IsNameOverride' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET IsNameOverride = CASE C.IsNameOfficial
                        WHEN 'T' THEN 'F'
                    END
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.IsNameOfficial || '=>' || CASE C.IsNameOfficial
                        WHEN 'T' THEN 'F'
                    END || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF
                (
                    (C.IsNameOfficial = 'T' OR D.IsNameOverride = 'F')
                    AND
                    C.Name <> D.Name
                )THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.Name' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET Name = C.Name
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Name) || '=>' || TEXT_TO_HTML(C.Name) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Type <> D.Type THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.Type' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET Type = C.Type
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Type) || '=>' || TEXT_TO_HTML(C.Type) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Comments, CHR(0)) <> COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRYSUBDIV.Comments' || '</td>'
                    || '<td>' || C.Country_ID || ', ' || C.Code || '</td>';
                    
                    UPDATE
                    COUNTRYSUBDIV
                    SET Comments = C.Comments
                    WHERE Country_ID = C.Country_ID
                    AND Code = C.Code;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Comments) || '=>' || TEXT_TO_HTML(C.Comments) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
            END LOOP;
            
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'COUNTRYSUBDIV' || '</td>'
                || '<td>' || C.Country_ID || ','
                || C.Code || ','
                || C.Parent$CountrySubdiv_Code || ','
                || C.ISO3166P1$Country_ID || ','
                || C.IsNameOfficial || ','
                || 'F' || ','
                || TEXT_TO_HTML(C.Name) || ','
                || TEXT_TO_HTML(C.Type) || ','
                || TEXT_TO_HTML(C.Comments) || '</td>';
                
                INSERT
                INTO COUNTRYSUBDIV
                (
                    COUNTRY_ID,
                    CODE,
                    PARENT$COUNTRYSUBDIV_CODE,
                    ISO3166P1$COUNTRY_ID,
                    COUNTRY_ALPHA2,
                    ID,
                    ISNAMEOFFICIAL,
                    ISNAMEOVERRIDE,
                    NAME,
                    SORTORDER,
                    TYPE,
                    UUID,
                    COMMENTS
                )
                SELECT C.Country_ID AS Country_ID,
                C.Code AS Code,
                C.Parent$CountrySubdiv_Code AS Parent$CountrySubdiv_Code,
                C.ISO3166P1$Country_ID AS ISO3166P1$Country_ID,
                Alpha2 AS Country_Alpha2,
                Alpha2 || '-' || C.Code AS ID,
                C.IsNameOfficial AS IsNameOfficial,
                'F' AS IsNameOverride,
                C.Name AS Name,
                (
                    SELECT MAX(SortOrder) + 1
                    FROM COUNTRYSUBDIV
                ) AS SortOrder,
                C.Type AS Type,
                UNCANONICALISE_UUID(UUID_Ver4) AS UUID,
                C.Comments AS Comments
                FROM COUNTRY
                WHERE ID = C.Country_ID;
                
                nInserted := nInserted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        ||  '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'COUNTRYSUBDIV.SortOrder' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO COUNTRYSUBDIV X
        USING
        (
            SELECT A.Country_ID,
            A.Code,
            ROW_NUMBER() OVER
            (
                ORDER BY B.Alpha2,
                A.DateEnd NULLS FIRST,
                C.SortOrderCountry,
                A.Name
            ) AS SortOrder
            FROM COUNTRYSUBDIV A
            INNER JOIN COUNTRY B
                ON A.Country_ID = B.ID
            LEFT OUTER JOIN
            (
                SELECT Country_ID,
                Code,
                MIN(SortOrderCountry) AS SortOrderCountry
                FROM S_COUNTRYSUBDIV
                GROUP BY Country_ID,
                Code
            ) C
                ON A.Country_ID = C.Country_ID
                        AND A.Code = C.Code
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Code = Y.Code)
        WHEN MATCHED THEN UPDATE SET X.SortOrder = Y.SortOrder
        WHERE X.SortOrder <> Y.SortOrder;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        ||  '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'COUNTRYSUBDIV.Geometry' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO COUNTRYSUBDIV X
        USING
        (
            SELECT A.Country_ID,
            A.CountrySubdiv_Code,
            B.Geometry
            FROM COUNTRYSUBDIV#GBRONSGEOGCODE A
            INNER JOIN GBRONSGEOGCODE B
                ON A.GBRONSGeogCode_ID = B.ID
            WHERE B.Geometry IS NOT NULL
            --
            UNION ALL
            --
            SELECT B.ID AS Country_ID,
            C.CountrySubdiv_Code,
            A.Geometry
            FROM S_COUNTRYSUBDIV_GEOMETRY A
            LEFT OUTER JOIN COUNTRY B
                ON A.ISO = B.ID
            LEFT OUTER JOIN UNIQUECOUNTR$COUNTRYSUBDIVNAME C
                ON TRIM
                        (
                            REGEXP_REPLACE
                            (
                                UPPER
                                (
                                    REPLACE
                                    (
                                        REGEXP_REPLACE(A.Name_1,'[[:blank:]]{2,}',' '),
                                        '-',
                                        ' '
                                    )
                                ),
                                '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                ''
                            )
                        ) = C.Name
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Code = CountrySubdiv_Code)
        WHEN MATCHED THEN UPDATE SET X.Geometry = Y.Geometry
        WHERE CASE
            WHEN X.Geometry IS NULL AND Y.Geometry IS NOT NULL THEN -3
            WHEN X.Geometry IS NOT NULL AND Y.Geometry IS NULL THEN -2
            WHEN X.Geometry IS NULL AND Y.Geometry IS NULL THEN 0
            ELSE DBMS_LOB.Compare
            (
                SDO_UTIL.To_KMLGeometry(X.Geometry),
                SDO_UTIL.To_KMLGeometry(Y.Geometry)
            )
        END <> 0;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRYSUBDIV')
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
            WHERE Table_Name IN ('COUNTRYSUBDIV')
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
        
        
        /*Do not uncomment until next version:
        Error report -
ORA-29273: HTTP request failed
ORA-06512: at "RD.GOOGLE", line 3115
ORA-29273: HTTP request failed
ORA-00600: internal error code, arguments: [], [], [], [], [], [], [], [], [], [], [], []
ORA-06512: at "SYS.UTL_HTTP", line 590
ORA-06512: at "SYS.UTL_HTTP", line 1203
ORA-06512: at "RD.GOOGLE", line 3115
ORA-06512: at line 9
29273. 00000 -  "HTTP request failed"
*Cause:    The UTL_HTTP package failed to execute the HTTP request.
*Action:   Use get_detailed_sqlerrm to check the detailed error message.
           Fix the error and retry the HTTP request.
Elapsed: 00:05:35.612
IF nInserted + nUpdated > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRYSUBDIV' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('COUNTRYSUBDIV', vGoogleOutput);
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(COALESCE(vGoogleOutput, vError)) || '</td>'
            || '</tr>';
            
        END IF;*/
        
        
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
    
    REFRESH_COUNTRYSUBDIV;
    
END;
/
*/