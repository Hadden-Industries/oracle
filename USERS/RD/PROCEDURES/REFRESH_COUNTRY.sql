SET DEFINE OFF;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRY
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRY ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'S_CNTR_AT',
                'S_COUNTRY_GEOMETRY',
                'S_COUNTRYDATESTART',
                'S_COUNTRYINFO',
                'S_COUNTRYPARENT',
                'S_COUNTRYUSERASSIGNMENT',
                'S_ISO3166_3'
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
                OWNNAME=>NULL,
                TABNAME=>C.Table_Name,
                METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE=>TRUE,
                ESTIMATE_PERCENT=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        --Oracle can't compile the staging table query when it is in the FOR loop, so need to have a physical table instead /sigh
        DELETE
        FROM S_COUNTRY;
        
        
        INSERT
        INTO S_COUNTRY
        (
            ID,
            PARENT$COUNTRY_ID,
            ALPHA2,
            INDEPENDENT,
            NAME,
            NAMEWITHOUTARTICLE,
            AREA,
            CALLINGCODE,
            DATEEND,
            DATESTART,
            FIPS10CODE,
            GEOMETRY,
            ISO3166P3,
            NAMEFULL,
            NAMETERRITORY,
            NUMERICCODE,
            POSTALCODEFORMAT,
            POSTALCODEREGEX,
            COMMENTS
        )
        --
        WITH COUNTRY_GEOMETRY AS
        (
            SELECT B.ISO3_Code AS Country_ID,
            A.Geometry
            FROM S_COUNTRY_GEOMETRY A
            INNER JOIN S_CNTR_AT B
                ON A.Cntr_ID = B.Cntr_ID
        ),
        --
        S_COUNTRY AS
        (
            SELECT ID AS Country_ID,
            'https://www.iso.org/obp/ui/#iso:code:3166:' || Alpha2 AS URL
            FROM COUNTRY AS OF PERIOD FOR VALID_TIME SYSDATE
            --WHERE ID = 'CUW'
        ),
        --
        XML AS
        (
            SELECT Country_ID,
            XMLPARSE
            (
                DOCUMENT REPLACE
                (
                    DBMS_LOB.Substr(Data, Position_End - Offset, Offset) || '</div>',
                    '&nbsp;',
                    ' '
                )
            ) AS xXML
            FROM
            (
                SELECT B.Country_ID,
                DBMS_LOB.INSTR(A.Data, '<div class="core-view-header">', 1, 1) AS Offset,
                DBMS_LOB.INSTR(A.Data, '<div class="related-pub"', 1, 1) AS Position_End,
                Data
                FROM LATEST$INBOUND A
                INNER JOIN S_COUNTRY B
                    ON A.URL = B.URL
            )
        ),
        --
        S_ISO3166_1 AS
        (
            SELECT Country_ID,
            Alpha2,
            Name,
            NameFull,
            ISO3166P3,
            NumericCode,
            Remarks,
            Independent,
            NameTerritory,
            Remarks1 --Currently always empty
            || CASE
                WHEN Remarks1 IS NOT NULL AND COALESCE(Remarks2, Remarks3) IS NOT NULL THEN CHR(10)
                ELSE NULL
            END
            || Remarks2
            || CASE
                WHEN COALESCE(Remarks1, Remarks2) IS NOT NULL AND Remarks3 IS NOT NULL THEN CHR(10)
                ELSE NULL
            END
            || Remarks3 AS Comments
            FROM
            (
                SELECT Country_ID,
                SINGLE_LINE(Alpha2) AS Alpha2,
                SINGLE_LINE(Name) AS Name,
                SINGLE_LINE(NameFull) AS NameFull,
                SINGLE_LINE(ISO3166P3) AS ISO3166P3,
                SINGLE_LINE(NumericCode) AS NumericCode,
                SINGLE_LINE(Remarks) AS Remarks,
                CASE SINGLE_LINE(Independent)
                    WHEN 'Yes' THEN 'T'
                    ELSE 'F'
                END AS Independent,
                SINGLE_LINE(NameTerritory) AS NameTerritory,
                SINGLE_LINE(StatusRemark) AS StatusRemark,
                SINGLE_LINE(Remarks1) AS Remarks1,
                SINGLE_LINE(Remarks2) AS Remarks2,
                SINGLE_LINE(Remarks3) AS Remarks3
                FROM
                (
                    SELECT Country_ID,
                    Name,
                    Value
                    FROM
                    (
                        SELECT XML.Country_ID,
                        A.ID,
                        B.Cl,
                        B.Div
                        FROM XML
                        INNER JOIN XMLTABLE
                        (
                            '/div/div/div' PASSING XML.xXML
                            COLUMNS ID FOR ORDINALITY,
                            Div XMLTYPE PATH '.'
                        ) A
                            ON 1 = 1
                        INNER JOIN XMLTABLE
                        (
                            '/div/div' PASSING A.Div
                            COLUMNS ID FOR ORDINALITY,
                            Cl VARCHAR2(4000 BYTE) PATH '@class',
                            Div VARCHAR2(4000 BYTE) PATH '.'
                        ) B
                            ON 1 = 1
                    )
                    PIVOT
                    (
                        MIN(Div) FOR Cl IN
                        (
                            'core-view-field-name' AS Name,
                            'core-view-field-value' AS Value
                        )
                    )
                    ORDER BY ID
                )
                PIVOT
                (
                    MIN(Value) FOR Name IN
                    (
                        'Alpha-2 code' AS Alpha2,
                        'Short name' AS NameUpper,
                        'Short name lower case' AS Name,
                        'Full name' AS NameFull,
                        'Alpha-3 code' AS ID,
                        'Alpha-4 code' AS ISO3166P3,
                        'Numeric code' AS NumericCode,
                        'Remarks' AS Remarks,
                        'Independent' AS Independent,
                        'Territory name' AS NameTerritory,
                        'Status' AS Status,
                        'Status remark' AS StatusRemark,
                        'Remark part 1' AS Remarks1,
                        'Remark part 2' AS Remarks2,
                        'Remark part 3' AS Remarks3
                    )
                )
                WHERE Country_ID = ID
                AND Status = 'Officially assigned'
            )
        )
        --
        SELECT /*+ NO_PARALLEL */
        A.Country_ID AS ID,
        D.Parent$Country_ID,
        A.Alpha2,
        A.Independent,
        A.Name,
        REPLACE
        (
            REPLACE(A.Name, ' (The)'),
            ' (the)'
        ) AS NameWithoutArticle,
        B.Area,
        CASE
            WHEN B.Phone IS NULL THEN NULL
            --North American Numbering Plan
            WHEN INSTR(B.Phone, '+1-') > 0 THEN 1 --Fully qualified under NANP
            ELSE TO_NUMBER
            (
                REGEXP_REPLACE(B.Phone, '[^[:digit:]]', '')
            )
        END AS CallingCode,
        A.DateEnd,
        COALESCE(A.DateStart, E.DateStart) AS DateStart,
        COALESCE(B.FIPS, B.EquivalentFIPS) AS FIPS10Code,
        SDO_CS.Transform
        (
            F.Geometry,
            --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
            4326
        ) AS Geometry,
        A.ISO3166P3,
        A.NameFull,
        A.NameTerritory,
        A.NumericCode,
        B.PostalCodeFormat,
        B.PostalCodeRegex,
        A.Comments
        FROM
        (
            SELECT Name,
            NameFull,
            Alpha2,
            Country_ID,
            NumericCode,
            Comments,
            Independent,
            ISO3166P3,
            NULL AS DateStart,
            NULL AS DateEnd,
            NameTerritory
            FROM S_ISO3166_1
            --
            UNION ALL
            --
            SELECT Name,
            NULL AS NameFull,
            Alpha2,
            Alpha3 AS Country_ID,
            NumericCode,
            Comments,
            Independent,
            ID AS ISO3166P3,
            DateStart,
            DateEnd,
            NULL AS NameTerritory
            FROM S_ISO3166_3
        ) A
        LEFT OUTER JOIN S_COUNTRYINFO B
            ON A.Country_ID = B.Alpha3
        LEFT OUTER JOIN S_COUNTRYPARENT D
            ON A.Country_ID = D.Country_ID
        LEFT OUTER JOIN S_COUNTRYDATESTART E
            ON A.Country_ID = E.Country_ID
        LEFT OUTER JOIN COUNTRY_GEOMETRY F
            ON A.Country_ID = F.Country_ID
        --
        UNION ALL
        --
        SELECT ID,
        Parent$Country_ID,
        Alpha2,
        Independent,
        Name,
        NameWithoutArticle,
        --UUID,
        Area,
        CallingCode,
        DateEnd,
        DateStart,
        FIPS10Code,
        Geometry,
        ISO3166P3,
        NameFull,
        NameTerritory,
        NumericCode,
        PostalCodeFormat,
        PostalCodeRegEx,
        Comments
        FROM S_COUNTRYUSERASSIGNMENT;
        
        FOR C IN
        (
            SELECT *
            FROM S_COUNTRY
            ORDER BY ID
        ) LOOP
            
            bExists := FALSE;
            
            FOR D IN
            (
                SELECT ID,
                Parent$Country_ID,
                Alpha2,
                Independent,
                Name,
                NameWithoutArticle,
                --UUID,
                Area,
                CallingCode,
                DateEnd,
                DateStart,
                FIPS10Code,
                Geometry,
                ISO3166P3,
                NameFull,
                NameTerritory,
                NumericCode,
                PostalCodeFormat,
                PostalCodeRegEx,
                Comments
                FROM COUNTRY
                WHERE ID = C.ID
            ) LOOP
                
                bExists := TRUE;
                
                IF COALESCE(C.Parent$Country_ID, CHR(0)) != COALESCE(D.Parent$Country_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Parent$Country_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Parent$Country_ID = C.Parent$Country_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Parent$Country_ID || '=>' || C.Parent$Country_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Alpha2 != D.Alpha2 THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Alpha2' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Alpha2 = C.Alpha2
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Alpha2 || '=>' || C.Alpha2 || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Independent != D.Independent THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Independent' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Independent = C.Independent
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Independent || '=>' || C.Independent || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Name != D.Name THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Name' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Name = C.Name,
                    --NameWithoutArticle is linked to the Name, so needs to be updated in same transaction
                    NameWithoutArticle = C.NameWithoutArticle
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Name || '=>' || C.Name || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Area, -1) != COALESCE(D.Area, -1) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Area' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Area = C.Area
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Area || '=>' || C.Area || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.CallingCode, -1) != COALESCE(D.CallingCode, -1) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.CallingCode' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET CallingCode = C.CallingCode
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.CallingCode || '=>' || C.CallingCode || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.DateEnd' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET DateEnd = C.DateEnd
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateEnd || '=>' || C.DateEnd || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateStart, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateStart, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.DateStart' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET DateStart = C.DateStart
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateStart || '=>' || C.DateStart || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.FIPS10Code, CHR(0)) != COALESCE(D.FIPS10Code, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.FIPS10Code' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET FIPS10Code = C.FIPS10Code
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.FIPS10Code || '=>' || C.FIPS10Code || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF CASE
                    WHEN C.Geometry IS NULL AND D.Geometry IS NOT NULL THEN -3
                    WHEN C.Geometry IS NOT NULL AND D.Geometry IS NULL THEN -2
                    WHEN C.Geometry IS NULL AND D.Geometry IS NULL THEN 0
                    ELSE DBMS_LOB.Compare
                    (
                        SDO_UTIL.To_KMLGeometry(C.Geometry),
                        SDO_UTIL.To_KMLGeometry(D.Geometry)
                    )
                    END != 0 THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Geometry' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Geometry = C.Geometry
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || 'Geometry is different' || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.ISO3166P3, CHR(0)) != COALESCE(D.ISO3166P3, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.ISO3166P3' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET ISO3166P3 = C.ISO3166P3
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.ISO3166P3 || '=>' || C.ISO3166P3 || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NameFull, CHR(0)) != COALESCE(D.NameFull, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.NameFull' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET NameFull = C.NameFull
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NameFull || '=>' || C.NameFull || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NameTerritory, CHR(0)) != COALESCE(D.NameTerritory, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.NameTerritory' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET NameTerritory = C.NameTerritory
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NameTerritory || '=>' || C.NameTerritory || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NumericCode, CHR(0)) != COALESCE(D.NumericCode, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.NumericCode' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET NumericCode = C.NumericCode
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NumericCode || '=>' || C.NumericCode || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.PostalCodeFormat, CHR(0)) != COALESCE(D.PostalCodeFormat, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.PostalCodeFormat' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET PostalCodeFormat = C.PostalCodeFormat
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.PostalCodeFormat || '=>' || C.PostalCodeFormat || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.PostalCodeRegEx, CHR(0)) != COALESCE(D.PostalCodeRegEx, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.PostalCodeRegEx' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET PostalCodeRegEx = C.PostalCodeRegEx
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.PostalCodeRegEx || '=>' || C.PostalCodeRegEx || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'COUNTRY.Comments' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    COUNTRY
                    SET Comments = C.Comments
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Comments || '=>' || C.Comments || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
            END LOOP;
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'COUNTRY' || '</td>'
                || '<td>'
                || 'ID : ' || C.ID || '<br />'
                || 'Parent$Country_ID : ' || C.Parent$Country_ID || '<br />'
                || 'Alpha2: ' || C.Alpha2 || '<br />'
                || 'Independent: ' || C.Independent || '<br />'
                || 'Name: ' || TEXT_TO_HTML(C.Name) || '<br />'
                || 'NameWithoutArticle: ' || TEXT_TO_HTML(C.NameWithoutArticle) || '<br />'
                || 'Area: ' || TO_CHAR(C.Area) || '<br />'
                || 'CallingCode: ' || TO_CHAR(C.CallingCode) || '<br />'
                || 'DateEnd: ' || TO_CHAR(C.DateEnd, 'YYYY-MM-DD') || '<br />'
                || 'DateStart: ' || TO_CHAR(C.DateStart, 'YYYY-MM-DD') || '<br />'
                || 'FIPS10Code: ' || C.FIPS10Code || '<br />'
                || 'ISO3166P3: ' || C.ISO3166P3 || '<br />'
                || 'NameFull: ' || TEXT_TO_HTML(C.NameFull) || '<br />'
                || 'NameTerritory: ' || TEXT_TO_HTML(C.NameTerritory) || '<br />'
                || 'NumericCode: ' || C.NumericCode || '<br />'
                || 'PostalCodeFormat: ' || TEXT_TO_HTML(C.PostalCodeFormat) || '<br />'
                || 'PostalCodeRegEx: ' || TEXT_TO_HTML(C.PostalCodeRegEx) || '<br />'
                || 'Comments: ' || TEXT_TO_HTML(C.Comments)
                || '</td>';
                
                INSERT
                INTO COUNTRY
                (
                    ID,
                    PARENT$COUNTRY_ID,
                    ALPHA2,
                    INDEPENDENT,
                    NAME,
                    NAMEWITHOUTARTICLE,
                    UUID,
                    AREA,
                    CALLINGCODE,
                    DATEEND,
                    DATESTART,
                    FIPS10CODE,
                    GEOMETRY,
                    ISO3166P3,
                    NAMEFULL,
                    NAMETERRITORY,
                    NUMERICCODE,
                    POSTALCODEFORMAT,
                    POSTALCODEREGEX,
                    COMMENTS
                )
                VALUES
                (
                    C.ID,
                    C.Parent$Country_ID,
                    C.Alpha2,
                    C.Independent,
                    C.Name,
                    C.NameWithoutArticle,
                    UNCANONICALISE_UUID(UUID_Ver4),
                    C.Area,
                    C.CallingCode,
                    C.DateEnd,
                    C.DateStart,
                    C.FIPS10Code,
                    C.Geometry,
                    C.ISO3166P3,
                    C.NameFull,
                    C.NameTerritory,
                    C.NumericCode,
                    C.PostalCodeFormat,
                    C.PostalCodeRegEx,
                    C.Comments
                );
                
                nInserted := nInserted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRY')
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
            WHERE Table_Name IN ('COUNTRY')
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
        
        
        IF nInserted + nUpdated > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRY' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('COUNTRY', vGoogleOutput);
                
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
    
    REFRESH_COUNTRY;
    
END;
/
*/