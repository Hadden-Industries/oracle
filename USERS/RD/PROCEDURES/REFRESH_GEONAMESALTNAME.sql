SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GEONAMESALTNAME
(
    gFull IN INTEGER DEFAULT 0,
    gDownload IN INTEGER DEFAULT 1
)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'GEONAMESALTNAME';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    vURL VARCHAR2(4000 BYTE) := Get_Table_Refresh_Source_URL(vTable_Name);
    gCLOB_Table CLOB_TABLE := CLOB_TABLE();
    
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
        
        IF gFull = 1 THEN
            
            IF gDownload = 1 THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMESALTNAME' || '</td>'
                || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
                
                BEGIN
                    
                    WGET(vURL);
                    
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
                
            END IF;
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DROP' || '</td>'
            || '<td>' || 'FOREIGN KEYS' || '</td>'
            || '<td>' || TEXT_TO_HTML(vTable_Name) || '</td>';
            
            BEGIN
                
                DROP_FK('RD', vTable_Name, gCLOB_Table, 0);
                
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
            || '<td>' || 'DROP' || '</td>'
            || '<td>' || 'CONSTRAINT' || '</td>'
            || '<td>' || TEXT_TO_HTML('GEONAMESALTNAME_PK') || '</td>';
            
            BEGIN
                
                EXECUTE IMMEDIATE('ALTER TABLE ' || vTable_Name || ' DROP CONSTRAINT GEONAMESALTNAME_PK');
                
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
            || '<td>' || 'TRUNCATE' || '</td>'
            || '<td>' || 'S_GEONAMESALTNAMEMERGE' || '</td>'
            || '<td>' || '' || '</td>';
            
            EXECUTE IMMEDIATE('TRUNCATE TABLE S_GEONAMESALTNAMEMERGE DROP STORAGE');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'S_GEONAMESALTNAMEMERGE' || '</td>'
            || '<td>' || '' || '</td>';
            
            INSERT
            INTO S_GEONAMESALTNAMEMERGE
            (
                ID,
                GEONAMES_ID,
                LANGUAGE_ID,
                NAME,
                COLLOQUIAL,
                HISTORIC,
                PREFERRED,
                SHORT,
                URL
            )
            --
            SELECT ID,
            GeoNames_ID,
            Language_ID,
            Name,
            Colloquial,
            Historic,
            Preferred,
            Short,
            URL
            FROM
            (
                SELECT ID,
                GeoNames_ID,
                Language_ID,
                Name,
                Colloquial,
                Historic,
                Preferred,
                Short,
                URL,
                ROW_NUMBER() OVER
                (
                    PARTITION BY GeoNames_ID,
                    Language_ID,
                    Name
                    ORDER BY Preferred DESC NULLS LAST,
                    Short DESC NULLS LAST,
                    URL DESC NULLS LAST,
                    Colloquial DESC NULLS LAST,
                    ID
                ) AS RN
                FROM
                (
                    SELECT /*+ USE_HASH(A E) */
                    A.ID,
                    A.GeoNames_ID,
                    COALESCE
                    (
                        B.ID,
                        C.ID,
                        D.ID,
                        E.ID,
                        (
                            SELECT ID
                            FROM LANGUAGE
                            WHERE Name = 'Undetermined'
                        )
                    ) AS Language_ID,
                    A.Name,
                    A.Colloquial,
                    A.Historic,
                    A.Preferred,
                    A.Short,
                    A.URL
                    FROM
                    (
                        SELECT AlternateNameID AS ID,
                        GeoNameID AS GeoNames_ID,
                        CASE
                            WHEN INSTR(ISOLanguage, '-') > 0 THEN SUBSTR(ISOLanguage, 1, INSTR(ISOLanguage, '-') - 1)
                            ELSE ISOLanguage
                        END AS ISOLanguage,
                        TRIM(AlternateName) AS Name,
                        CASE IsPreferredName
                            WHEN 1 THEN 'T'
                            ELSE NULL
                        END AS Preferred,
                        CASE IsShortName
                            WHEN 1 THEN 'T'
                            ELSE NULL
                        END AS Short,
                        CASE IsColloquial
                            WHEN 1 THEN 'T'
                            ELSE NULL
                        END AS Colloquial,
                        CASE IsHistoric
                            WHEN 1 THEN 'T'
                            ELSE NULL
                        END AS Historic,
                        CASE
                            WHEN ISOLanguage = 'link' THEN 'T'
                            ELSE NULL
                        END AS URL
                        FROM S_GEONAMESALTNAME
                        WHERE (ISOLanguage != 'post' OR ISOLanguage IS NULL)
                    ) A
                    LEFT OUTER JOIN LANGUAGE B
                        ON A.ISOLanguage = B.Part1
                    LEFT OUTER JOIN LANGUAGE C
                        ON A.ISOLanguage = C.Part2B
                    LEFT OUTER JOIN LANGUAGE D
                        ON A.ISOLanguage = D.Part2T
                    LEFT OUTER JOIN LANGUAGE E
                        ON A.ISOLanguage = E.ID
                    INNER JOIN GEONAMES F
                        ON A.GeoNames_ID = F.ID
                )
            )
            WHERE RN = 1;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('S_GEONAMESALTNAMEMERGE')
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
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || vTable_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            DELETE
            FROM GEONAMESALTNAME
            WHERE ID NOT IN
            (
                SELECT ID
                FROM S_GEONAMESALTNAMEMERGE
                WHERE ID IS NOT NULL
            );
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'MERGE' || '</td>'
            || '<td>' || vTable_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            MERGE
            INTO GEONAMESALTNAME X
            USING 
            (
                SELECT ID,
                GeoNames_ID,
                Language_ID,
                Name,
                Colloquial,
                Historic,
                Preferred,
                Short,
                URL
                FROM S_GEONAMESALTNAMEMERGE
                --
                MINUS
                --
                SELECT ID,
                GeoNames_ID,
                Language_ID,
                Name,
                Colloquial,
                Historic,
                Preferred,
                Short,
                URL
                FROM GEONAMESALTNAME
            ) Y
                ON (X.ID = Y.ID)
            WHEN MATCHED THEN UPDATE SET X.GeoNames_ID = Y.GeoNames_ID,
            X.Language_ID = Y.Language_ID,
            X.Name = Y.Name,
            X.Colloquial = Y.Colloquial,
            X.Historic = Y.Historic,
            X.Preferred = Y.Preferred,
            X.Short = Y.Short,
            X.URL = Y.URL
            WHEN NOT MATCHED THEN INSERT
            (
                ID,
                GEONAMES_ID,
                LANGUAGE_ID,
                NAME,
                COLLOQUIAL,
                HISTORIC,
                PREFERRED,
                SHORT,
                URL
            )
            VALUES
            (
                Y.ID,
                Y.GeoNames_ID,
                Y.Language_ID,
                Y.Name,
                Y.Colloquial,
                Y.Historic,
                Y.Preferred,
                Y.Short,
                Y.URL
            );
            
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
            || '<td>' || 'ADD' || '</td>'
            || '<td>' || 'CONSTRAINT' || '</td>'
            || '<td>' || TEXT_TO_HTML('GEONAMESALTNAME_PK') || '</td>';
            
            BEGIN
                
                EXECUTE IMMEDIATE('ALTER TABLE ' || vTable_Name || ' ADD CONSTRAINT GEONAMESALTNAME_PK PRIMARY KEY (GEONAMES_ID, LANGUAGE_ID, NAME)');
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
            END;
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN (vTable_Name)
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
                    ESTIMATE_PERCENT=>1
                );
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
            END LOOP;
            
            
            IF gCLOB_Table.Last != 0 THEN
                
                FOR i IN gCLOB_Table.First..gCLOB_Table.Last LOOP
                    
                    vMsg := vMsg || CHR(10)
                    || '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'CREATE' || '</td>'
                    || '<td>' || 'FOREIGN KEY' || '</td>'
                    || '<td>' || TEXT_TO_HTML(gCLOB_Table(i)) || '</td>';
                    
                    BEGIN
                        
                        EXECUTE IMMEDIATE(gCLOB_Table(i));
                        
                        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                        || '</tr>';
                        
                    EXCEPTION
                    WHEN OTHERS THEN
                        
                        vError := SUBSTRB(SQLErrM, 1, 255);
                        
                        vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                        || '</tr>';
                        
                    END;
                    
                END LOOP;
                
            END IF;
            
            
            FOR C IN
            (
                SELECT GeoNames_ID,
                Name
                FROM GEONAMESALTNAME
                WHERE GeoNames_ID IN
                (
                    SELECT /*+ OPT_ESTIMATE(QUERY_BLOCK ROWS=10) */
                    GeoNames_ID
                    FROM GEONAMESALTNAME
                    WHERE Language_ID = 'eng'
                    AND Preferred = 'T'
                    GROUP BY GeoNames_ID
                    HAVING COUNT(*) > 1
                )
                AND Language_ID = 'eng'
                AND Preferred = 'T'
                ORDER BY GeoNames_ID,
                Name
            ) LOOP
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'Primary duplicates' || '</td>'
                || '<td>' || TO_CHAR(C.GeoNames_ID) || '</td>'
                || '<td>' || TEXT_TO_HTML(C.Name) || '</td>'
                || '<td>' || '' || '</td>'
                || '</tr>';
                
            END LOOP;
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN (vTable_Name)
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
        
        IF gCLOB_Table.Last != 0 THEN
            
            FOR i IN gCLOB_Table.First..gCLOB_Table.Last LOOP
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'CREATE' || '</td>'
                || '<td>' || 'FOREIGN KEY' || '</td>'
                || '<td>' || TEXT_TO_HTML(gCLOB_Table(i)) || ';' || '</td>';
                
            END LOOP;
            
        END IF;
        
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
    
    REFRESH_GEONAMESALTNAME
    (
        gFull=>1,
        gDownload=>0
    );
    
END;
/
*/