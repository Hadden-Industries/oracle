SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_TOWNNAME
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'TOWNNAME ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variable
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
        || '<td>' || 'UNIQUECOUNTRYSUBDIV$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM UNIQUECOUNTRYSUBDIV$TOWNNAME
        WHERE (Name, Country_ID, CountrySubdiv_Code) NOT IN
        (
            SELECT Name,
            Country_ID,
            CountrySubdiv_Code
            FROM V_UNIQUECOUNTRYSUBDIV$TOWNNAME
            WHERE Name IS NOT NULL
            AND Country_ID IS NOT NULL
            AND CountrySubdiv_Code IS NOT NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'UNIQUECOUNTRYSUBDIV$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE /*+ USE_NL(X) */
        INTO UNIQUECOUNTRYSUBDIV$TOWNNAME X
        USING
        (
            SELECT Country_ID,
            CountrySubdiv_Code,
            Name,
            GeoNames_ID
            FROM V_UNIQUECOUNTRYSUBDIV$TOWNNAME
            --
            MINUS
            --
            SELECT Country_ID,
            CountrySubdiv_Code,
            Name,
            GeoNames_ID
            FROM UNIQUECOUNTRYSUBDIV$TOWNNAME
        ) Y
            ON (X.Name = Y.Name
                    AND X.Country_ID = Y.Country_ID
                    AND X.CountrySubdiv_Code = Y.CountrySubdiv_Code)
        WHEN MATCHED THEN UPDATE SET X.GeoNames_ID = Y.GeoNames_ID
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            COUNTRYSUBDIV_CODE,
            NAME,
            GEONAMES_ID
        )
        VALUES
        (
            Y.Country_ID,
            Y.CountrySubdiv_Code,
            Y.Name,
            Y.GeoNames_ID
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNIQUECOUNTRYSUBDIV$TOWNNAME'
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'UNIQUECOUNTRY$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM UNIQUECOUNTRY$TOWNNAME
        WHERE (Name, Country_ID) NOT IN
        (
            SELECT Name,
            Country_ID
            FROM V_UNIQUECOUNTRY$TOWNNAME
            WHERE Name IS NOT NULL
            AND Country_ID IS NOT NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'UNIQUECOUNTRY$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE /*+ USE_NL(X) */
        INTO UNIQUECOUNTRY$TOWNNAME X
        USING
        (
            SELECT Country_ID,
            Name,
            GeoNames_ID
            FROM V_UNIQUECOUNTRY$TOWNNAME
            --
            MINUS
            --
            SELECT Country_ID,
            Name,
            GeoNames_ID
            FROM UNIQUECOUNTRY$TOWNNAME
        ) Y
            ON (X.Name = Y.Name
                    AND X.Country_ID = Y.Country_ID)
        WHEN MATCHED THEN UPDATE SET X.GeoNames_ID = Y.GeoNames_ID
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            NAME,
            GEONAMES_ID
        )
        VALUES
        (
            Y.Country_ID,
            Y.Name,
            Y.GeoNames_ID
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNIQUECOUNTRY$TOWNNAME'
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
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'UNIQUE$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM UNIQUE$TOWNNAME
        WHERE Name NOT IN
        (
            SELECT Name
            FROM V_UNIQUE$TOWNNAME
            WHERE Name IS NOT NULL
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'UNIQUE$TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE /*+ USE_NL(X) */
        INTO UNIQUE$TOWNNAME X
        USING
        (
            SELECT Name,
            GeoNames_ID
            FROM V_UNIQUE$TOWNNAME
            --
            MINUS
            --
            SELECT Name,
            GeoNames_ID
            FROM UNIQUE$TOWNNAME
        ) Y
            ON (X.Name = Y.Name)
        WHEN MATCHED THEN UPDATE SET X.GeoNames_ID = Y.GeoNames_ID
        WHEN NOT MATCHED THEN INSERT
        (
            NAME,
            GEONAMES_ID
        )
        VALUES
        (
            Y.Name,
            Y.GeoNames_ID
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'UNIQUE$TOWNNAME'
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
        
        DBMS_OUTPUT.Put_Line(DBMS_LOB.SUBSTR(vMsg));
        
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
    
    REFRESH_TOWNNAME;
    
END;
/
*/