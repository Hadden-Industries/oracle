SET DEFINE OFF;
SET SERVEROUTPUT ON;

CREATE OR REPLACE
PROCEDURE REFRESH_UNLOCODE
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'UNLOCODE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variable
    
    nCountUnmatched PLS_INTEGER := 0;
    nDeleted SIMPLE_INTEGER := 0;
    nDeletedFunctions SIMPLE_INTEGER := 0;
    nMerged SIMPLE_INTEGER := 0;
    nInsertedFunctions SIMPLE_INTEGER := 0;
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
                'S_UNLOCODE',
                'UNLOCODEFUNCTION',
                'UNLOCODESTATUS'
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
        
        
        FOR C IN
        (
            SELECT Status,
            COUNT(*) AS Cnt
            FROM S_UNLOCODE
            WHERE Status IS NOT NULL
            AND Status NOT IN
            (
                SELECT ID
                FROM UNLOCODESTATUS
            )
            GROUP BY Status
        ) LOOP
            
            nCountUnmatched := nCountUnmatched + C.Cnt;
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'UNLOCODESTATUS' || '</td>'
            || '<td>' || 'Missing: ' || C.Status || '</td>'
            || '<td>' || TO_CHAR(C.Cnt) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nCountUnmatched > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNLOCODESTATUS'
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
            SELECT UNLOCODEFunction_ID,
            COUNT(*) AS Cnt
            FROM V_UNLOCODE#UNLOCODEFUNCTION
            WHERE UNLOCODEFunction_ID NOT IN
            (
                SELECT ID
                FROM UNLOCODEFUNCTION
            )
            GROUP BY UNLOCODEFunction_ID
        ) LOOP
            
            nCountUnmatched := nCountUnmatched + C.Cnt;
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'UNLOCODEFUNCTION' || '</td>'
            || '<td>' || 'Missing: ' || C.UNLOCODEFunction_ID || '</td>'
            || '<td>' || TO_CHAR(C.Cnt) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nCountUnmatched > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNLOCODEFUNCTION'
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
        
        --test for country subdivisions that do not currently exist
        FOR C IN
        (
            SELECT /*+ NO_PARALLEL */
            A.Country || ' ' || A.Location AS ID,
            A.Name,
            B.Name AS Country_Name,
            A.Subdivision,
            A.CoOrdinates
            FROM S_UNLOCODE A
            INNER JOIN COUNTRY AS OF PERIOD FOR VALID_TIME SYSDATE B
                    ON A.Country = B.Alpha2
            WHERE A.Subdivision IS NOT NULL
            AND CASE
                WHEN Country = 'GB' AND Location IN ('DSE', 'FLI') AND Subdivision = 'CWD' THEN 'FLN'
                WHEN Country = 'GB' AND Location IN ('LSD') AND Subdivision = 'WYK' THEN 'BRD'
                --Indonesia's Papua https://www.iso.org/obp/ui/#iso:code:3166:ID
                WHEN Country= 'ID' AND Subdivision = 'IJ' THEN 'PP'
                --http://en.wikipedia.org/wiki/Provinces_of_Kenya
                WHEN Country = 'KE' AND Location IN ('LIM') AND Subdivision = '200' THEN '13'
                WHEN Country = 'KE' AND Location IN ('ARI') AND Subdivision = '400' THEN '22'
                WHEN Country = 'KE' AND Location IN ('MWI') AND Subdivision = '400' THEN '18'
                WHEN Country = 'KE' AND Location IN ('DDB') AND Subdivision = '500' THEN '07'
                WHEN Country = 'KE' AND Location IN ('MUH') AND Subdivision = '600' THEN '17'
                WHEN Country = 'KE' AND Location IN ('SIA') AND Subdivision = '600' THEN '38'
                WHEN Country = 'KE' AND Location IN ('RNA') AND Subdivision = '700' THEN '31'
                WHEN Country = 'LV' AND Location IN ('VIL') AND Subdivision = 'BL' THEN '108'
                WHEN Country = 'LV' AND Location IN ('PAC') AND Subdivision = 'BU' THEN '016'
                WHEN Country = 'LV' AND Location IN ('DGP') AND Subdivision = 'DW' THEN 'DGV'
                WHEN Country = 'LV' AND Location IN ('AKI') AND Subdivision = 'JK' THEN '004'
                WHEN Country = 'LV' AND Location IN ('CEN') AND Subdivision = 'JL' THEN '041'
                WHEN Country = 'LV' AND Location IN ('PRE') AND Subdivision = 'PR' THEN '073'
                WHEN Country = 'LV' AND Location IN ('BMT') AND Subdivision = 'RI' THEN 'RIX'
                WHEN Country = 'PL' AND Location IN ('SWA') AND Subdivision = 'PO' THEN 'WP'
                WHEN Country = 'VN' AND Location IN ('HTY') AND Subdivision = '15' THEN 'HN'
                ELSE NULL
            END IS NULL
            AND (B.ID, A.Subdivision) NOT IN
            (
                SELECT Country_ID,
                Code
                FROM COUNTRYSUBDIV AS OF PERIOD FOR VALID_TIME SYSDATE
            )
            ORDER BY B.ID,
            A.Subdivision,
            A.Name
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'S_UNLOCODE' || '</td>'
            || '<td>' || 'Subdivision' || '</td>'
            || '<td>' || C.ID || ' (' || TEXT_TO_HTML(C.Name) || ') in ' || TEXT_TO_HTML(C.Country_Name) || ' has subdivision ' || TEXT_TO_HTML(C.Subdivision) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'UNLOCODE#UNLOCODEFUNCTION' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM UNLOCODE#UNLOCODEFUNCTION
        WHERE (Country_ID, UNLOCODE_Code, UNLOCODEFunction_ID)
        NOT IN
        (
            SELECT /*+ HASH_AJ */
            Country_ID,
            UNLOCODE_Code,
            UNLOCODEFunction_ID
            FROM V_UNLOCODE#UNLOCODEFUNCTION
            WHERE Country_ID IS NOT NULL
            AND UNLOCODE_Code IS NOT NULL
            AND UNLOCODEFunction_ID IS NOT NULL
        );
        
        nDeletedFunctions := nDeletedFunctions + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'UNLOCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM UNLOCODE
        WHERE (Country_ID, Code)
        NOT IN
        (
            SELECT /*+ HASH_AJ */
            Country_ID,
            Code
            FROM V_UNLOCODE
            WHERE Country_ID IS NOT NULL
            AND Code IS NOT NULL
        );
        
        nDeleted := nDeleted + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'UNLOCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO UNLOCODE X
        USING
        (
            SELECT Country_ID,
            Code,
            Country_Alpha2,
            CountrySubdiv_Code,
            ID,
            UNLOCODEStatus_ID,
            Name,
            NameOfficial,
            DateReference,
            CASE
                WHEN COALESCE(Latitude, Longitude) IS NOT NULL THEN SDO_GEOMETRY
                (
                    2001,
                    4326, --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                    SDO_POINT_TYPE
                    (
                        Longitude,
                        Latitude,
                        NULL
                    ),
                    NULL,
                    NULL
                )
                ELSE NULL
            END AS Geometry,
            IATA_ID,
            Comments
            FROM
            (
                SELECT Country_ID,
                Code,
                Country_Alpha2,
                CountrySubdiv_Code,
                ID,
                UNLOCODEStatus_ID,
                Name,
                NameOfficial,
                DateReference,
                Latitude,
                Longitude,
                IATA_ID,
                Comments
                FROM V_UNLOCODE
                --
                MINUS
                --
                SELECT A.Country_ID,
                A.Code,
                A.Country_Alpha2,
                A.CountrySubdiv_Code,
                A.ID,
                A.UNLOCODEStatus_ID,
                A.Name,
                A.NameOfficial,
                A.DateReference,
                A.Geometry.SDO_POINT.Y AS Latitude,
                A.Geometry.SDO_POINT.X AS Longitude,
                A.IATA_ID,
                A.Comments
                FROM UNLOCODE A
            )
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Code = Y.Code)
        WHEN MATCHED THEN UPDATE SET X.Country_Alpha2 = Y.Country_Alpha2,
        X.CountrySubdiv_Code = Y.CountrySubdiv_Code,
        X.UNLOCODEStatus_ID = Y.UNLOCODEStatus_ID,
        X.ID = Y.ID,
        X.Name = Y.Name,
        X.NameOfficial = Y.NameOfficial,
        X.DateReference = Y.DateReference,
        X.Geometry = Y.Geometry,
        X.IATA_ID = Y.IATA_ID,
        X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            CODE,
            COUNTRY_ALPHA2,
            COUNTRYSUBDIV_CODE,
            UNLOCODESTATUS_ID,
            ID,
            NAME,
            NAMEOFFICIAL,
            UUID,
            DATEREFERENCE,
            GEOMETRY,
            IATA_ID,
            COMMENTS
        )
        VALUES
        (
            Y.Country_ID,
            Y.Code,
            Y.Country_Alpha2,
            Y.CountrySubdiv_Code,
            Y.UNLOCODEStatus_ID,
            Y.ID,
            Y.Name,
            Y.NameOfficial,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.DateReference,
            Y.Geometry,
            Y.IATA_ID,
            Y.Comments
        );
        
        nMerged := nMerged + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'UNLOCODE' || '</td>'
        || '<td>' || 'CountrySubdiv_Code' || '</td>';
        
        MERGE
        INTO UNLOCODE X
        USING
        (
            SELECT Country_ID,
            Code,
            CountrySubdiv_Code
            FROM
            (
                SELECT /* INDEX(A UNLOCODE_GEOMETRY_IX) */
                A.Country_ID,
                A.Code,
                B.Country_ID AS CountrySubdiv_Country_ID,
                B.Code AS CountrySubdiv_Code,
                ROW_NUMBER() OVER
                (
                    PARTITION BY A.Country_ID, A.Code
                    ORDER BY B.Parent$CountrySubdiv_Code NULLS LAST,
                    A.Code
                ) AS RN
                FROM UNLOCODE A
                INNER JOIN COUNTRYSUBDIV B
                    ON SDO_INSIDE(A.Geometry, B.Geometry) = 'TRUE'
                WHERE A.CountrySubdiv_Code IS NULL
            )
            WHERE RN = 1
            AND Country_ID = CountrySubdiv_Country_ID
        ) Y
            ON (X.Country_ID = Y.Country_ID
                    AND X.Code = Y.Code)
        WHEN MATCHED THEN UPDATE SET X.CountrySubdiv_Code = Y.CountrySubdiv_Code,
        X.Comments = X.Comments
        || CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE CHR(10)
        END
        || 'Country subdivision code deduced from the coordinates';
        
        nMerged := nMerged + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNLOCODE'
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
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'UNLOCODE#UNLOCODEFUNCTION' || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT
        INTO UNLOCODE#UNLOCODEFUNCTION
        (
            COUNTRY_ID,
            UNLOCODE_CODE,
            UNLOCODEFUNCTION_ID
        )
        --
        SELECT Country_ID,
        UNLOCODE_Code,
        UNLOCODEFunction_ID
        FROM V_UNLOCODE#UNLOCODEFUNCTION
        WHERE Country_ID IS NOT NULL
        AND UNLOCODE_Code IS NOT NULL
        AND UNLOCODEFunction_ID IS NOT NULL
        AND (Country_ID, UNLOCODE_Code, UNLOCODEFunction_ID) NOT IN
        (
            SELECT /*+ HASH_AJ */
            Country_ID,
            UNLOCODE_Code,
            UNLOCODEFunction_ID
            FROM UNLOCODE#UNLOCODEFUNCTION
        );
        
        nInsertedFunctions := nInsertedFunctions + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNLOCODE#UNLOCODEFUNCTION'
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
                'UNLOCODE',
                'UNLOCODE#UNLOCODEFUNCTION'
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
            || '<td>' || 'UNLOCODE' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('UNLOCODE', vGoogleOutput);
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(COALESCE(vGoogleOutput, vError)) || '</td>'
            || '</tr>';
            
        END IF;
        
        
        IF nDeletedFunctions + nInsertedFunctions > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'UNLOCODE#UNLOCODEFUNCTION' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('UNLOCODE#UNLOCODEFUNCTION', vGoogleOutput);
                
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
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_UNLOCODE;
    
END;
/
*/