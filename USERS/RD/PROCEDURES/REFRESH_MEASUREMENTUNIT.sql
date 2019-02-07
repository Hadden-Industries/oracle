SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_MEASUREMENTUNIT
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'MEASUREMENTUNIT ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    bExists BOOLEAN := FALSE;
    nDeleted SIMPLE_INTEGER := 0;
    nInserted SIMPLE_INTEGER := 0;
    nUpdated SIMPLE_INTEGER := 0;
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
        
        FOR C IN
        (
            SELECT ID,
            MeasurementUnitLevel_ID,
            MeasurementUnitStatus_ID,
            Name,
            UUID,
            ConversionFactor,
            Symbol,
            Comments
            FROM MEASUREMENTUNIT
            WHERE ID NOT IN
            (
                SELECT CASE
                    WHEN Level_Category IS NOT NULL THEN NULL
                    --each code value from UNECE Recommendation 21 shall be prefixed with an “X”, resulting in a 3 alphanumeric code when used as a unit of measure
                    ELSE 'X'
                END
                || Common_Code AS ID
                FROM S_MEASUREMENT
                WHERE Group_Number IS NULL
            )
            ORDER BY ID
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'MEASUREMENTUNIT' || '</td>'
            || '<td>'
            || 'ID: ' || TEXT_TO_HTML(C.ID) || '<br />'
            || 'MeasurementUnitLevel_ID: ' || TEXT_TO_HTML(C.MeasurementUnitLevel_ID) || '<br />'
            || 'MeasurementUnitStatus_ID: ' || TEXT_TO_HTML(C.MeasurementUnitStatus_ID) || '<br />'
            || 'Name: ' || TEXT_TO_HTML(C.Name) || '<br />'
            || 'ConversionFactor: ' || TEXT_TO_HTML(C.ConversionFactor) || '<br />'
            || 'Symbol: ' || TEXT_TO_HTML(C.Symbol) || '<br />'
            || 'UUID: ' || C.UUID || '<br />'
            || 'Comments: ' || TEXT_TO_HTML(C.Comments)
            || '</td>';
            
            DELETE
            FROM MEASUREMENTUNIT
            WHERE MEASUREMENTUNIT.ID = C.ID;
            
            nDeleted := nDeleted + SQL%ROWCOUNT;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT CASE
                WHEN Level_Category IS NOT NULL THEN NULL
                --each code value from UNECE Recommendation 21 shall be prefixed with an “X”, resulting in a 3 alphanumeric code when used as a unit of measure
                ELSE 'X'
            END
            || Common_Code AS ID,
            CASE
                WHEN Level_Category IS NOT NULL THEN CASE
                    WHEN INSTR(Level_Category, CHR(10)) > 0 THEN SUBSTR(Level_Category, 1, INSTR(Level_Category, CHR(10)) - 2)
                    ELSE Level_Category
                END
            ELSE '21'
            END AS MeasurementUnitLevel_ID,
            Status AS MeasurementUnitStatus_ID,
            Name,
            Conversion_Factor AS ConversionFactor,
            Symbol,
            Description AS Comments
            FROM S_MEASUREMENT
            WHERE Group_Number IS NULL
            ORDER BY ID
        ) LOOP
            
            bExists := FALSE;
            
            FOR D IN
            (
                SELECT ID,
                MeasurementUnitLevel_ID,
                MeasurementUnitStatus_ID,
                Name,
                --UUID,
                ConversionFactor,
                Symbol,
                Comments
                FROM MEASUREMENTUNIT
                WHERE MEASUREMENTUNIT.ID = C.ID
            ) LOOP
                
                bExists := TRUE;
                

                IF C.MeasurementUnitLevel_ID != D.MeasurementUnitLevel_ID THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.MeasurementUnitLevel_ID' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET MeasurementUnitLevel_ID = C.MeasurementUnitLevel_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.MeasurementUnitLevel_ID) || '=>' || TEXT_TO_HTML(C.MeasurementUnitLevel_ID) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.MeasurementUnitStatus_ID, CHR(0)) != COALESCE(D.MeasurementUnitStatus_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.MeasurementUnitStatus_ID' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET MeasurementUnitStatus_ID = C.MeasurementUnitStatus_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.MeasurementUnitStatus_ID) || '=>' || TEXT_TO_HTML(C.MeasurementUnitStatus_ID) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Name != D.Name THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.Name' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET Name = C.Name
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Name) || '=>' || TEXT_TO_HTML(C.Name) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.ConversionFactor, CHR(0)) != COALESCE(D.ConversionFactor, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.ConversionFactor' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET ConversionFactor = C.ConversionFactor
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.ConversionFactor) || '=>' || TEXT_TO_HTML(C.ConversionFactor) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Symbol, CHR(0)) != COALESCE(D.Symbol, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.Symbol' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET Symbol = C.Symbol
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Symbol) || '=>' || TEXT_TO_HTML(C.Symbol) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'MEASUREMENTUNIT.Comments' || '</td>'
                    || '<td>' || TEXT_TO_HTML(C.ID) || '</td>';
                    
                    UPDATE
                    MEASUREMENTUNIT
                    SET Comments = C.Comments
                    WHERE ID = C.ID;
                    
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
                || '<td>' || 'MEASUREMENTUNIT' || '</td>'
                || '<td>'
                || 'ID: ' || TEXT_TO_HTML(C.ID) || '<br />'
                || 'MeasurementUnitLevel_ID: ' || TEXT_TO_HTML(C.MeasurementUnitLevel_ID) || '<br />'
                || 'MeasurementUnitStatus_ID: ' || TEXT_TO_HTML(C.MeasurementUnitStatus_ID) || '<br />'
                || 'Name: ' || TEXT_TO_HTML(C.Name) || '<br />'
                || 'ConversionFactor: ' || TEXT_TO_HTML(C.ConversionFactor) || '<br />'
                || 'Symbol: ' || TEXT_TO_HTML(C.Symbol) || '<br />'
                || 'Comments: ' || TEXT_TO_HTML(C.Comments)
                || '</td>';
                
                INSERT
                INTO MEASUREMENTUNIT
                (
                    ID,
                    MEASUREMENTUNITLEVEL_ID,
                    MEASUREMENTUNITSTATUS_ID,
                    NAME,
                    UUID,
                    CONVERSIONFACTOR,
                    SYMBOL,
                    COMMENTS
                )
                VALUES
                (
                    C.ID,
                    C.MeasurementUnitLevel_ID,
                    C.MeasurementUnitStatus_ID,
                    C.Name,
                    UNCANONICALISE_UUID(UUID_Ver4),
                    C.ConversionFactor,
                    C.Symbol,
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
            WHERE Table_Name IN
            (
                'MEASUREMENTUNIT'
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'MEASUREMENTUNIT'
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
        
        
        IF nDeleted + nInserted + nUpdated > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'MEASUREMENTUNIT' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('MEASUREMENTUNIT', vGoogleOutput);
                
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
        
        DBMS_OUTPUT.Put_Line(DBMS_LOB.Substr(vMsg));
    
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
    
    REFRESH_MEASUREMENTUNIT;
    
END;
/
*/