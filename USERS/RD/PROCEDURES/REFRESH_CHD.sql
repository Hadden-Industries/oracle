SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_CHD(gDownload IN INTEGER DEFAULT 1)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'CHD ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vFileNamePrevious VARCHAR2(4000 BYTE) := NULL;
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    vURLIndex VARCHAR2(75 BYTE) := 'https://geoportal.statistics.gov.uk/geoportal/catalog/content/filelist.page';
    vURLCHD VARCHAR2(4000 BYTE) := '';
    
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
        
        
        IF gDownload = 1 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'FIND_URL_ON_WEB_PAGE' || '</td>'
            || '<td>' || 'Code_History_Database' || '</td>'
            || '<td>' || '' || '</td>';
            
            BEGIN
                
                vURLCHD := FIND_URL_ON_WEB_PAGE(vURLIndex, 'Code_History_Database_(');
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END;
            
            
            IF vURLCHD IS NOT NULL THEN
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            ELSE
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END IF;
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || TEXT_TO_HTML('S_CHD') || '</td>'
            || '<td>' || TEXT_TO_HTML(vURLCHD) || '</td>';
            
            BEGIN
                
                SELECT 'File already exists'
                INTO vError
                FROM DIR
                WHERE FileType = 'File'
                AND INSTR(vURLCHD, FileName) > 0;
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                
                NULL;
                
            END;
            
            
            BEGIN
                
                SELECT FileName
                INTO vFileNamePrevious
                FROM DIR
                WHERE FileName LIKE
                (
                    SELECT REPLACE(Location, '*', '%')
                    FROM USER_EXTERNAL_LOCATIONS
                    WHERE Table_Name = 'S_CHD'
                );
                
            EXCEPTION
            WHEN NO_DATA_FOUND THEN
                
                vFileNamePrevious := NULL;
                
            END;
            
            
            BEGIN
                
                WGET(vURLCHD);
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
                RAISE HANDLED;
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            IF vFileNamePrevious IS NOT NULL THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'DELETE' || '</td>'
                || '<td>' || TEXT_TO_HTML('S_CHD') || '</td>'
                || '<td>' || TEXT_TO_HTML(vFileNamePrevious) || '</td>';
                
                BEGIN
                    
                    UTL_FILE.FRemove('RD', vFileNamePrevious);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                    || '</tr>';
                    
                EXCEPTION
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                    || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
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
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('S_CHD')
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
        
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'GBRSTATUTORYINSTRUMENT' || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT
        INTO GBRSTATUTORYINSTRUMENT
        (
            ID,
            NAME
        )
        --
        SELECT SI_ID,
        COALESCE(SI_Title, SI_ID) AS SI_Title
        FROM
        (
            SELECT SI_ID,
            SI_Title,
            ROW_NUMBER() OVER (PARTITION BY SI_ID ORDER BY LENGTH(SI_Title) DESC) AS RN
            FROM S_CHD
            WHERE SI_ID IS NOT NULL
            AND SI_ID NOT IN
            (
                SELECT ID
                FROM GBRSTATUTORYINSTRUMENT
            )
            GROUP BY SI_ID,
            SI_Title
        )
        WHERE RN = 1;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF SQL%ROWCOUNT > 0 THEN
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('GBRSTATUTORYINSTRUMENT')
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
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DISABLE CONSTRAINT' || '</td>'
        || '<td>' || 'CHD_CHD_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        EXECUTE IMMEDIATE('ALTER TABLE CHD DISABLE CONSTRAINT CHD_CHD_FK');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'CHD' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO CHD X
        USING
        (
            SELECT ID,
            DateStart,
            Parent$CHD_ID,
            Parent$CHD_DateStart,
            GBRONSRGC_ID,
            GBRStatutoryInstrument_ID,
            cym$Name,
            DateEnd,
            Name
            FROM
            (
                SELECT A.GeogCD AS ID,
                A.Oper_Date AS DateStart,
                --Check correct length
                CASE
                    WHEN LENGTHB(TRIM(A.ParentCD)) = 9 THEN A.ParentCD
                    ELSE NULL
                END AS Parent$CHD_ID,
                CASE
                    WHEN LENGTHB(TRIM(A.ParentCD)) = 9 THEN MIN(B.Oper_Date)
                    ELSE NULL
                END AS Parent$CHD_DateStart,
                A.EntityCD AS GBRONSRGC_ID,
                A.SI_ID AS GBRStatutoryInstrument_ID,
                A.GeogNmW AS cym$Name,
                CASE
                    --when the start and end dates are the same, assume it existed just for that day
                    WHEN A.Oper_Date = A.Term_Date THEN A.Term_Date + 1 - (1/(24*60*60))
                    ELSE A.Term_Date
                END AS DateEnd,
                A.GeogNm AS Name
                FROM S_CHD A
                LEFT OUTER JOIN S_CHD B
                    ON A.ParentCD = B.GeogCD
                            AND A.Oper_Date >= B.Oper_Date
                --Same-day rename violates primary key and logic
                WHERE NOT (A.GeogCD = 'E05002426' AND A.SI_ID = '1111/1001')
                GROUP BY A.GeogCD,
                A.Oper_Date,
                A.ParentCD,
                A.EntityCD,
                A.SI_ID,
                A.GeogNmW,
                A.Term_Date,
                A.GeogNm
                --
                MINUS
                --
                SELECT ID,
                DateStart,
                Parent$CHD_ID,
                Parent$CHD_DateStart,
                GBRONSRGC_ID,
                GBRStatutoryInstrument_ID,
                cym$Name,
                DateEnd,
                Name
                FROM CHD
            )
            --Insert parent CHD IDs first to help prevent FK errors
            ORDER BY CASE
            WHEN Parent$CHD_ID IS NULL THEN 0
            ELSE 1
            END,
            ID,
            DateStart
        ) Y
            ON (X.ID = Y.ID
                    AND X.DateStart = Y.DateStart)
        WHEN MATCHED THEN UPDATE SET X.Parent$CHD_ID = Y.Parent$CHD_ID,
        X.Parent$CHD_DateStart = Y.Parent$CHD_DateStart,
        X.GBRONSRGC_ID = Y.GBRONSRGC_ID,
        X.GBRStatutoryInstrument_ID = Y.GBRStatutoryInstrument_ID,
        X.cym$Name = Y.cym$Name,
        X.DateEnd = Y.DateEnd,
        X.Name = Y.Name
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            DATESTART,
            PARENT$CHD_ID,
            PARENT$CHD_DATESTART,
            GBRONSRGC_ID,
            GBRSTATUTORYINSTRUMENT_ID,
            CYM$NAME,
            DATEEND,
            NAME
        )
        VALUES
        (
            Y.ID,
            Y.DateStart,
            Y.Parent$CHD_ID,
            Y.Parent$CHD_DateStart,
            Y.GBRONSRGC_ID,
            Y.GBRStatutoryInstrument_ID,
            Y.cym$Name,
            Y.DateEnd,
            Y.Name
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('CHD')
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
            WHERE Table_Name IN ('CHD')
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
        || '<td>' || 'CHD_CHD_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        EXECUTE IMMEDIATE('ALTER TABLE CHD ENABLE CONSTRAINT CHD_CHD_FK');
        
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
    
    REFRESH_CHD(gDownload=>0);
    
END;
/
*/