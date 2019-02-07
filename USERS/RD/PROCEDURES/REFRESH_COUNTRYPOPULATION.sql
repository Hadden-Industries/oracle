SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_COUNTRYPOPULATION
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'COUNTRYPOPULATION ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nUnmatchedVariant SIMPLE_INTEGER := 0;
    nDeleted SIMPLE_INTEGER := 0;
    nMerged SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
    --Error variables
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
            WHERE Table_Name IN ('S_COUNTRYPOPULATION')
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
                ownname=>NULL,
                tabname=>C.Table_Name,
                method_opt=>'FOR ALL COLUMNS SIZE SKEWONLY',
                cascade=>TRUE,
                estimate_percent=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        SELECT COUNT(*)
        INTO nUnmatchedVariant
        FROM
        (
            SELECT VarID
            FROM S_COUNTRYPOPULATION
            WHERE (VarID, Variant) NOT IN
            (
                SELECT ID,
                Name
                FROM POPULATIONPROJECTIONVARIANT
            )
            GROUP BY VarID
        );
        
        IF nUnmatchedVariant > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'POPULATIONPROJECTIONVARIANT' || '</td>'
            || '<td>' || 'Missing' || '</td>'
            || '<td>' || TO_CHAR(nUnmatchedVariant) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        ELSE
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('POPULATIONPROJECTIONVARIANT')
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
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'COUNTRYPOPULATION' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM COUNTRYPOPULATION
        WHERE
        (
            Country_ID,
            PopulationProjectionVariant_ID,
            Year
        ) NOT IN
        (
            SELECT B.ID AS Country_ID,
            C.ID AS PopulationProjectionVariant_ID,
            A.Time AS Year
            FROM S_COUNTRYPOPULATION A
            INNER JOIN COUNTRY B
                ON LPAD(A.LocID, 3, '0') = B.NumericCode
                        --The values pertain to July 1st in every year
                        AND
                        (
                            B.DateStart IS NULL
                            OR B.DateStart <= TO_DATE(TO_CHAR(A.Time) || '0701', 'YYYYMMDD')
                        )
                        AND
                        (
                            B.DateEnd IS NULL
                            OR B.DateEnd > TO_DATE(TO_CHAR(A.Time) || '0701', 'YYYYMMDD')
                        )
            LEFT OUTER JOIN POPULATIONPROJECTIONVARIANT C
                ON A.VarID = C.ID
            WHERE B.ID IS NOT NULL
            AND C.ID IS NOT NULL
            AND A.Time IS NOT NULL
        );
        
        nDeleted := nDeleted + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'COUNTRYPOPULATION' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO COUNTRYPOPULATION X
        USING
        (
            SELECT B.ID AS Country_ID,
            C.ID AS PopulationProjectionVariant_ID,
            A.Time AS Year,
            ((A.PopFemale + A.PopMale) * 1000) AS Total,
            (A.PopFemale * 1000) AS Female,
            (A.PopMale * 1000) AS Male
            FROM S_COUNTRYPOPULATION A
            INNER JOIN COUNTRY B
                ON LPAD(A.LocID, 3, '0') = B.NumericCode
                        --The values pertain to July 1st in every year
                        AND
                        (
                            B.DateStart IS NULL
                            OR B.DateStart <= TO_DATE(TO_CHAR(A.Time) || '0701', 'YYYYMMDD')
                        )
                        AND
                        (
                            B.DateEnd IS NULL
                            OR B.DateEnd > TO_DATE(TO_CHAR(A.Time) || '0701', 'YYYYMMDD')
                        )
            LEFT OUTER JOIN POPULATIONPROJECTIONVARIANT C
                ON A.VarID = C.ID
        ) Y
             ON (X.Country_ID = Y.Country_ID
                    AND X.PopulationProjectionVariant_ID = Y.PopulationProjectionVariant_ID
                    AND X.Year = Y.Year)
        WHEN MATCHED THEN UPDATE SET X.Total = Y.Total,
        X.Female = Y.Female,
        X.Male = Y.Male
        WHERE X.Total != Y.Total
        OR COALESCE(X.Female, -1) != COALESCE(Y.Female, -1)
        OR COALESCE(X.Male, -1) != COALESCE(Y.Male, -1)
        WHEN NOT MATCHED THEN INSERT
        (
            COUNTRY_ID,
            POPULATIONPROJECTIONVARIANT_ID,
            YEAR,
            TOTAL,
            FEMALE,
            MALE
        )
        VALUES
        (
            Y.Country_ID,
            Y.PopulationProjectionVariant_ID,
            Y.Year,
            Y.Total,
            Y.Female,
            Y.Male
        );
        
        nMerged := nMerged + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRYPOPULATION')
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRYPOPULATION')
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
        
        
        IF ((nDeleted + nMerged) > 0) THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRYPOPULATION' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('COUNTRYPOPULATION', vGoogleOutput);
                
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
    
    REFRESH_COUNTRYPOPULATION;
    
END;
/
*/