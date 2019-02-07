SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GBRONSGEOGCODE
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'GBRONSGEOGCODE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nUnmatched PLS_INTEGER := 0;
    vTimeStampFormat CONSTANT CHAR(10 BYTE) := 'HH24:MI:SS';
    
    --Error variables
    HANDLED EXCEPTION;
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.ENABLE(NULL);
    
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
        || '<td>' || 'GBRONSGEOGCODE' || '</td>'
        || '<td>' || 'Parent$GBRONSGeogCode_ID' || '</td>';
        
        DELETE
        FROM GBRONSGEOGCODE
        WHERE Parent$GBRONSGeogCode_ID IN
        (
            SELECT ID
            FROM GBRONSGEOGCODE
            WHERE Parent$GBRONSGeogCode_ID NOT IN
            (
                SELECT ID
                FROM CHD AS OF PERIOD FOR VALID_TIME SYSDATE
            )
            --
            UNION
            --
            SELECT ID
            FROM GBRONSGEOGCODE
            WHERE Parent$GBRONSGeogCode_ID IN
            (
                SELECT ID
                FROM GBRONSGEOGCODE
                WHERE Parent$GBRONSGeogCode_ID NOT IN
                (
                    SELECT ID
                    FROM CHD AS OF PERIOD FOR VALID_TIME SYSDATE
                )
            )
            --
            UNION
            --
            SELECT ID
            FROM GBRONSGEOGCODE
            WHERE Parent$GBRONSGeogCode_ID IN
            (
                SELECT ID
                FROM GBRONSGEOGCODE
                WHERE Parent$GBRONSGeogCode_ID IN
                (
                    SELECT ID
                    FROM GBRONSGEOGCODE
                    WHERE Parent$GBRONSGeogCode_ID NOT IN
                    (
                        SELECT ID
                        FROM CHD AS OF PERIOD FOR VALID_TIME SYSDATE
                    )
                )
            )
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'GBRONSGEOGCODE' || '</td>'
        || '<td>' || 'ID' || '</td>';
        
        DELETE
        FROM GBRONSGEOGCODE
        WHERE ID NOT IN
        (
            SELECT ID
            FROM CHD AS OF PERIOD FOR VALID_TIME SYSDATE
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DISABLE CONSTRAINT' || '</td>'
        || '<td>' || 'GBRONSGEOGCODE_PARENT_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        EXECUTE IMMEDIATE('ALTER TABLE GBRONSGEOGCODE DISABLE CONSTRAINT GBRONSGEOGCODE_PARENT_FK');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'GBRONSGEOGCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO GBRONSGEOGCODE X
        USING
        (
            SELECT A.ID,
            CASE
                WHEN SYSDATE NOT BETWEEN B.DateStart AND COALESCE(B.DateEnd, TO_DATE('99991231', 'YYYYMMDD')) THEN NULL
                ELSE A.Parent$CHD_ID
            END AS Parent$GBRONSGeogCode_ID,
            A.GBRONSRGC_ID,
            A.GBRStatutoryInstrument_ID,
            A.DateStart,
            A.cym$NAME,
            SDO_CS.Transform(C.Geometry, 4326) AS Geometry,
            A.Name
            FROM CHD AS OF PERIOD FOR VALID_TIME SYSDATE A
            LEFT OUTER JOIN CHD B
                ON A.Parent$CHD_ID = B.ID
                        AND A.Parent$CHD_DateStart = B.DateStart
            LEFT OUTER JOIN GBRBOUNDARY C
                ON A.ID = C.Code
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.PARENT$GBRONSGEOGCODE_ID = Y.PARENT$GBRONSGEOGCODE_ID,
        X.GBRONSRGC_ID = Y.GBRONSRGC_ID,
        X.GBRSTATUTORYINSTRUMENT_ID = Y.GBRSTATUTORYINSTRUMENT_ID,
        X.DATESTART = Y.DATESTART,
        X.CYM$NAME = Y.CYM$NAME,
        X.GEOMETRY = Y.GEOMETRY,
        X.NAME = Y.NAME
        WHERE COALESCE(X.PARENT$GBRONSGEOGCODE_ID,'-1') != COALESCE(Y.PARENT$GBRONSGEOGCODE_ID,'-1')
        OR X.GBRONSRGC_ID != Y.GBRONSRGC_ID
        OR COALESCE(X.GBRSTATUTORYINSTRUMENT_ID,'-1') != COALESCE(Y.GBRSTATUTORYINSTRUMENT_ID,'-1')
        OR X.DATESTART != Y.DATESTART
        OR COALESCE(X.CYM$NAME,'-1') != COALESCE(Y.CYM$NAME,'-1')
        OR
        (
            X.Geometry IS NULL
            AND Y.Geometry IS NOT NULL
        )
        OR
        (
            X.Geometry IS NOT NULL
            AND Y.Geometry IS NULL
        )
        OR
        (
            X.Geometry IS NOT NULL
            AND Y.Geometry IS NOT NULL
            AND SDO_EQUAL(X.Geometry, Y.Geometry) = 'FALSE'
        )
        OR COALESCE(X.NAME,'-1') != COALESCE(Y.NAME,'-1')
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            PARENT$GBRONSGEOGCODE_ID,
            GBRONSRGC_ID,
            GBRSTATUTORYINSTRUMENT_ID,
            DATESTART,
            CYM$NAME,
            GEOMETRY,
            NAME
        )
        VALUES
        (
            Y.ID,
            Y.PARENT$GBRONSGEOGCODE_ID,
            Y.GBRONSRGC_ID,
            Y.GBRSTATUTORYINSTRUMENT_ID,
            Y.DATESTART,
            Y.CYM$NAME,
            Y.GEOMETRY,
            Y.NAME
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('GBRONSGEOGCODE')
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
            WHERE Table_Name IN ('GBRONSGEOGCODE')
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
        || '<td>' || 'GBRONSGEOGCODE_PARENT_FK' || '</td>'
        || '<td>' || '' || '</td>';
        
        EXECUTE IMMEDIATE('ALTER TABLE GBRONSGEOGCODE ENABLE CONSTRAINT GBRONSGEOGCODE_PARENT_FK');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'CHECK' || '</td>'
        || '<td>' || 'ISO country subdivisions not present' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT COUNT(*)
        INTO nUnmatched
        FROM COUNTRYSUBDIV#GBRONSGEOGCODE A
        INNER JOIN COUNTRYSUBDIV B
            ON A.Country_ID = B.Country_ID
                    AND A.CountrySubdiv_Code = B.ID
        WHERE A.GBRONSGeogCode_ID NOT IN
        (
            SELECT ID
            FROM GBRONSGEOGCODE
            --and have associated boundaries
            WHERE Geometry IS NOT NULL
        )
        AND B.Type NOT IN
        (
            'Country',
            'N/A',
            'Province'
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(nUnmatched) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'CHECK' || '</td>'
        || '<td>' || 'Non-metropolitan Districts with no boundaries' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT COUNT(B.ID)
        INTO nUnmatched
        FROM GBRONSRGC A
        INNER JOIN GBRONSGEOGCODE B
            ON A.ID = B.GBRONSRGC_ID
        WHERE A.Name = 'Non-metropolitan Districts'
        AND B.Geometry IS NULL;
        
        vMsg := vMsg || '<td>' || TO_CHAR(nUnmatched) || '</td>'
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
        
        DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(vMsg));
        
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
        
        DBMS_OUTPUT.PUT_LINE('EMAIL: ' || vError);
        
    END;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_GBRONSGEOGCODE;
    
END;
/
*/