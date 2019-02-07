SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GEONAMESADMINCODE
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'GEONAMESADMINCODE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vURL1 VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/admin1CodesASCII.txt';
    vURL2 VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/admin2Codes.txt';
    cCLOB CLOB := EMPTY_CLOB();
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    
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
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL1) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL1, 'GEONAMESADMINCODE');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'ROLLBACK' || '</td>'
            || '<td>' || USER || '</td>'
            || '<td>' || '' || '</td>';
            
            ROLLBACK;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            RAISE HANDLED;
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL2) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL2, 'GEONAMESADMINCODE');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'ROLLBACK' || '</td>'
            || '<td>' || USER || '</td>'
            || '<td>' || '' || '</td>';
            
            ROLLBACK;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            RAISE HANDLED;
            
        END;
        
        
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
        || '<td>' || TEXT_TO_HTML(vURL1) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL1);
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL2) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL2);
        
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'TRUNCATE' || '</td>'
        || '<td>' || 'S_GEONAMESADMIN1CODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            UTL_FILE.FRemove(USER, 'S_GEONAMESADMIN1CODE.tsv');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'S_GEONAMESADMIN1CODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT A.Data
        INTO cCLOB
        FROM INBOUND A
        WHERE A.TableLookup_Name = 'GEONAMESADMINCODE'
        AND A.URL = vURL1
        AND A.DateTimeX =
        (
            SELECT MAX(B.DateTimex)
            FROM INBOUND B
            WHERE A.TableLookup_Name = B.TableLookup_Name
            AND B.URL = vURL1
        );
        
        CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESADMIN1CODE.tsv');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_GEONAMESADMIN1CODE')
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
        || '<td>' || 'TRUNCATE' || '</td>'
        || '<td>' || 'S_GEONAMESADMIN2CODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            UTL_FILE.FRemove(USER, 'S_GEONAMESADMIN2CODE.tsv');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'S_GEONAMESADMIN2CODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT A.Data
        INTO cCLOB
        FROM INBOUND A
        WHERE A.TableLookup_Name = 'GEONAMESADMINCODE'
        AND A.URL = vURL2
        AND A.DateTimeX =
        (
            SELECT MAX(B.DateTimex)
            FROM INBOUND B
            WHERE A.TableLookup_Name = B.TableLookup_Name
            AND B.URL = vURL2
        );
        
        CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESADMIN2CODE.tsv');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_GEONAMESADMIN2CODE')
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
        || '<td>' || 'GEONAMESADMINCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM GEONAMESADMINCODE
        WHERE ID NOT IN
        (
            SELECT ID
            FROM S_GEONAMESADMIN1CODE
            WHERE ID IS NOT NULL
            --
            UNION ALL
            --
            SELECT ID
            FROM S_GEONAMESADMIN2CODE
            WHERE ID IS NOT NULL
        )
        AND
        (
            --Do not delete the Greater London Area third-level (from GeoNames) subdivision as this was manually entered
            Parent$GeonamesAdminCode_ID != 'GB.ENG.GLA'
            --The above filter condition necessitates a not-NULL parent, but these should also be considered
            OR Parent$GeonamesAdminCode_ID IS NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DISABLE CONSTRAINT' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE_GEONAMES_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE GEONAMESADMINCODE DISABLE CONSTRAINT GEONAMESADMINCODE_GEONAMES_FK');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
            || '</tr>';
                            
        END;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO GEONAMESADMINCODE X
        USING
        (
            SELECT ID,
            COALESCE(Name, NameOfficial) AS Name,
            NameOfficial,
            GeoNamesID AS GeoNames_ID
            FROM
            (
                SELECT ID,
                NameOfficial,
                Name,
                GeoNamesID
                FROM S_GEONAMESADMIN1CODE
                --
                UNION ALL
                --
                SELECT ID,
                NameOfficial,
                Name,
                GeoNamesID
                FROM S_GEONAMESADMIN2CODE
            )
            WHERE ID IS NOT NULL
            --
            MINUS
            --
            SELECT ID,
            Name,
            NameOfficial,
            GeoNames_ID
            FROM GEONAMESADMINCODE
            ORDER BY ID
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Name = Y.Name,
        X.NameOfficial = Y.NameOfficial,
        X.GeoNames_ID = Y.GeoNames_ID
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            NAME,
            NAMEOFFICIAL,
            GEONAMES_ID
        )
        VALUES
        (
            Y.ID,
            Y.Name,
            Y.NameOfficial,
            Y.GeoNames_ID
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE' || '</td>'
        || '<td>' || TEXT_TO_HTML('Country_ID IS NULL') || '</td>';
        
        MERGE
        INTO GEONAMESADMINCODE X
        USING
        (
            SELECT A.ID,
            B.ID Country_ID
            FROM GEONAMESADMINCODE A
            INNER JOIN COUNTRY B
                ON SUBSTR(A.ID, 1, INSTR(A.ID, '.') - 1) = B.Alpha2
            WHERE A.Country_ID IS NULL
            AND (B.DateStart IS NULL OR TRUNC(SYSDATE) >= DateStart)
            AND (B.DateEnd IS NULL OR TRUNC(SYSDATE) <= DateEnd)
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Country_ID = Y.Country_ID;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE' || '</td>'
        || '<td>' || TEXT_TO_HTML('Parent$GeoNamesAdminCode_ID IS NULL') || '</td>';
        
        MERGE
        INTO GEONAMESADMINCODE X
        USING
        (
            SELECT ID,
            Parent$GeonamesAdminCode_ID
            FROM
            (
                SELECT ID,
                SUBSTR
                (
                    ID,
                    1,
                    INSTR(ID, '.', 1, 2) - 1
                ) AS Parent$GeonamesAdminCode_ID
                FROM GEONAMESADMINCODE
                WHERE INSTR(ID, '.', 1, 2) > 0
                AND Parent$GeonamesAdminCode_ID IS NULL
            )
            --has the corresponding foreign key
            WHERE Parent$GeonamesAdminCode_ID IN
            (
                SELECT ID
                FROM GEONAMESADMINCODE
            )
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Parent$GeonamesAdminCode_ID = Y.Parent$GeonamesAdminCode_ID;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'UPDATE' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE' || '</td>'
        || '<td>' || TEXT_TO_HTML('No country subdivisions') || '</td>';
        
        UPDATE
        GEONAMESADMINCODE A
        SET A.Comments = 'No ISO 3166-2 subdivisions exists for this country'
        WHERE NOT EXISTS
        (
            SELECT NULL
            FROM COUNTRYSUBDIV B
            WHERE A.Country_ID = B.Country_ID
        )
        AND
        (
            A.Comments != 'No ISO 3166-2 subdivisions exists for this country'
            OR
            A.Comments IS NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('GEONAMESADMINCODE')
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
            WHERE Table_Name IN ('GEONAMESADMINCODE')
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
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'ENABLE CONSTRAINT' || '</td>'
        || '<td>' || 'GEONAMESADMINCODE_GEONAMES_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE GEONAMESADMINCODE ENABLE CONSTRAINT GEONAMESADMINCODE_GEONAMES_FK');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
            || '</tr>';
                            
        END;
        
        
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
        
        DBMS_OUTPUT.Put_Line('EMAIL: ' || vError);
        
    END;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_GEONAMESADMINCODE;
    
END;
/

--see mapping
SELECT A.ID,
A.Name,
A.NameOfficial,
C.*
FROM GEONAMESADMINCODE A
INNER JOIN COUNTRYSUBDIV C
    ON A.Country_ID = C.Country_ID
            AND A.CountrySubdiv_Code = C.Code
WHERE A.Country_ID = 'GRC'
ORDER BY A.ID;

--make sure second level subdivisions are correct
SELECT A.ID,
A.CountrySubdiv_Code,
A.Parent$GeoNamesAdminCode_ID,
B.CountrySubdiv_Code AS Parent$CountrySubdiv_Code,
C.Parent$CountrySubdiv_Code AS Calc_Parent$CountrySubdiv_Code
FROM GEONAMESADMINCODE A
INNER JOIN GEONAMESADMINCODE B
    ON A.Parent$GeoNamesAdminCode_ID = B.ID
INNER JOIN COUNTRYSUBDIV C
    ON A.Country_ID = C.Country_ID
            AND A.CountrySubdiv_Code = C.Code
WHERE COALESCE(B.CountrySubdiv_Code, CHR(0)) != COALESCE(C.Parent$CountrySubdiv_Code, CHR(0));
*/