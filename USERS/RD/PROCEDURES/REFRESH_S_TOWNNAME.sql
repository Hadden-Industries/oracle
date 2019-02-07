SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_S_TOWNNAME(gFull INTEGER DEFAULT 0)
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'S_TOWNNAME ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    bFull BOOLEAN := CASE gFull
        WHEN 1 THEN TRUE
        ELSE FALSE
    END;
    
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
        
        
        IF bFull THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'TRUNCATE' || '</td>'
            || '<td>' || 'S_TOWNNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            EXECUTE IMMEDIATE('TRUNCATE TABLE S_TOWNNAME REUSE STORAGE');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
        
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'S_TOWNNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            INSERT
            INTO S_TOWNNAME
            (
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                GEONAMES_ID,
                GEONAMESFEATURECODE_ID,
                DATEMODIFIED,
                NAME,
                PRIORITY,
                POPULATION
            )
            --
            WITH GEONAMES_S AS
            (
                SELECT ID,
                Country_ID,
                CountrySubdiv_Code,
                Name,
                GeoNamesFeatureCode_ID,
                DateModified,
                Population
                FROM GEONAMES
                WHERE GeoNamesFeatureClass_ID =
                (
                    SELECT ID
                    FROM GEONAMESFEATURECLASS
                    WHERE Name = 'City, village,...'
                )
            )
            --
            SELECT Country_ID,
            CountrySubdiv_Code,
            ID AS GeoNames_ID,
            GeoNamesFeatureCode_ID,
            DateModified,
            Name,
            Priority,
            Population
            FROM
            (
                SELECT Country_ID,
                CountrySubdiv_Code,
                ID,
                --Only keep the first 100 bytes
                SUBSTRB
                (
                    TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE(Name, '-', ' ')
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ),
                    1,
                    100
                ) AS Name,
                1 AS Priority,
                Population,
                GeoNamesFeatureCode_ID,
                DateModified
                FROM GEONAMES_S
                --
                UNION ALL
                --
                SELECT DISTINCT
                B.Country_ID,
                B.CountrySubdiv_Code,
                B.ID,
                --Only keep the first 100 bytes e.g. for Bangkok's full name (1609350)
                SUBSTRB
                (
                    TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE(A.Name, '-', ' ')
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ),
                    1,
                    100
                ) AS Name,
                CASE
                    WHEN A.Preferred = 'T' AND A.Language_ID = 'eng' THEN 2
                    WHEN A.Colloquial = 'T' THEN -1
                    WHEN A.Historic = 'T' THEN -2
                ELSE 0
                END AS Priority,
                B.Population,
                B.GeoNamesFeatureCode_ID,
                B.DateModified
                FROM GEONAMESALTNAME A
                INNER JOIN GEONAMES_S B
                    ON A.GeoNames_ID = B.ID
                WHERE (A.URL IS NULL OR A.URL = 'F')
            )
            WHERE Name IS NOT NULL;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN
                (
                    'S_TOWNNAME'
                )
                ORDER BY Table_Name
            )
            LOOP
                
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
            
            
        ELSE
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'S_TOWNNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            DELETE
            FROM S_TOWNNAME
            WHERE GeoNames_ID IN
            (
               SELECT GeoNamesID
               FROM S_GEONAMES_M
                --
                UNION ALL
                --
                SELECT GeoNameID
                FROM S_GEONAMESALTNAME_M
                --
                UNION ALL
                --
                SELECT GeoNamesID
                FROM S_GEONAMES_D
                --
                UNION ALL
                --
                SELECT GeoNamesID
                FROM S_GEONAMESALTNAME_D
            );
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'S_TOWNNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            INSERT
            INTO S_TOWNNAME
            (
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                GEONAMES_ID,
                GEONAMESFEATURECODE_ID,
                DATEMODIFIED,
                NAME,
                PRIORITY,
                POPULATION
            )
            --
            WITH GEONAMES_S AS
            (
                SELECT ID,
                Country_ID,
                CountrySubdiv_Code,
                Name,
                GeoNamesFeatureCode_ID,
                DateModified,
                Population
                FROM GEONAMES
                WHERE GeoNamesFeatureClass_ID =
                (
                    SELECT ID
                    FROM GEONAMESFEATURECLASS
                    WHERE Name = 'City, village,...'
                )
                AND ID IN
                (
                    SELECT GeoNamesID
                    FROM S_GEONAMES_M
                    --
                    UNION ALL
                    --
                    SELECT GeoNameID
                    FROM S_GEONAMESALTNAME_M
                    --
                    UNION ALL
                    --
                    SELECT GeoNamesID
                    FROM S_GEONAMES_D
                    --
                    UNION ALL
                    --
                    SELECT GeoNamesID
                    FROM S_GEONAMESALTNAME_D
                )
            )
            --
            SELECT Country_ID,
            CountrySubdiv_Code,
            ID AS GeoNames_ID,
            GeoNamesFeatureCode_ID,
            DateModified,
            Name,
            Priority,
            Population
            FROM
            (
                SELECT Country_ID,
                CountrySubdiv_Code,
                ID,
                --Only keep the first 100 bytes
                SUBSTRB
                (
                    TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE(Name, '-', ' ')
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ),
                    1,
                    100
                ) AS Name,
                1 AS Priority,
                Population,
                GeoNamesFeatureCode_ID,
                DateModified
                FROM GEONAMES_S
                --
                UNION ALL
                --
                SELECT DISTINCT
                B.Country_ID,
                B.CountrySubdiv_Code,
                B.ID,
                --Only keep the first 100 characters e.g. for Bangkok's full name (1609350)
                SUBSTRB
                (
                    TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE(A.Name, '-', ' ')
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ),
                    1,
                    100
                ) AS Name,
                CASE
                    WHEN A.Preferred = 'T' AND A.Language_ID = 'eng' THEN 2
                    WHEN A.Colloquial = 'T' THEN -1
                    WHEN A.Historic = 'T' THEN -2
                ELSE 0
                END AS Priority,
                B.Population,
                B.GeoNamesFeatureCode_ID,
                B.DateModified
                FROM GEONAMESALTNAME A
                INNER JOIN GEONAMES_S B
                    ON A.GeoNames_ID = B.ID
                WHERE (A.URL IS NULL OR A.URL = 'F')
            )
            WHERE Name IS NOT NULL;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
        
        END IF;
        
        
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('S_TOWNNAME')
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
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'TOWNNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_SCHEDULER.Create_Job
            (
                job_name=>'JOB_' || SUBSTRB('REFRESH_TOWNNAME', 1, 26), --IN VARCHAR2
                job_type=>'PLSQL_BLOCK', --IN VARCHAR2
                job_action=>'REFRESH_TOWNNAME;', --IN VARCHAR2
                number_of_arguments=>0, --IN PLS_INTEGER DEFAULT 0
                start_date=>NULL, --IN TIMESTAMP WITH TIME ZONE DEFAULT NULL
                repeat_interval=>NULL, --IN VARCHAR2 DEFAULT NULL
                end_date=>NULL, --IN TIMESTAMP WITH TIME ZONE DEFAULT NULL
                job_class=>'DEFAULT_JOB_CLASS', --IN VARCHAR2 DEFAULT 'DEFAULT_JOB_CLASS'
                enabled=>TRUE, --IN BOOLEAN DEFAULT FALSE
                auto_drop=>TRUE, --IN BOOLEAN DEFAULT TRUE
                comments=>NULL --IN VARCHAR2 DEFAULT NULL
            );
            
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
        
        vError := SUBSTRB(SQLErrM, 1, 248);
        
        DBMS_OUTPUT.Put_Line('EMAIL: ' || vError);
        
    END;
    
    
END;
/

/*
--Full refresh
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_S_TOWNNAME(1);
    
END;
/
*/