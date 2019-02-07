SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GEONAMES
(
    gFull IN INTEGER DEFAULT 0,
    gDownload IN INTEGER DEFAULT 1
)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'GEONAMES';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    cCLOB CLOB := EMPTY_CLOB();
    gCLOB_Table CLOB_TABLE := CLOB_TABLE();
    nAlreadyRunning SIMPLE_INTEGER := 0;
    nCorrectDownload SIMPLE_INTEGER := 0;
    nRowsMarketAffected SIMPLE_INTEGER := 0;
    vDateYesterday VARCHAR2(10 BYTE) := TO_CHAR(TRUNC(SYSDATE) - 1, 'YYYY-MM-DD');
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    vURL VARCHAR2(4000 BYTE) := Get_Table_Refresh_Source_URL(vTable_Name);
    vURLAltDel VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/alternateNamesDeletes-';
    vURLAltMod VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/alternateNamesModifications-';
    vURLDel VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/deletes-';
    vURLMod VARCHAR2(4000 BYTE) := 'http://download.geonames.org/export/dump/modifications-';
    
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
        
        
        SELECT COUNT(*)
        INTO nAlreadyRunning
        FROM USER_SESSIONS
        WHERE Module = 'REFRESH_' || vTable_Name;
        
        
        IF nAlreadyRunning > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'REFRESH_' || vTable_Name || '</td>'
            || '<td>' || 'Already running?' || '</td>'
            || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        ELSE
            
            DBMS_APPLICATION_INFO.Set_Module
            (
               module_name=>'REFRESH_' || vTable_Name,
               action_name=>'Running'
            );
            
        END IF;
        
        
        IF gFull = 1 THEN
            
            
            IF gDownload = 1 THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMES' || '</td>'
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
            || '<td>' || 'TRUNCATE' || '</td>'
            || '<td>' || 'S_GEONAMESMERGE' || '</td>'
            || '<td>' || '' || '</td>';
            
            EXECUTE IMMEDIATE('TRUNCATE TABLE S_GEONAMESMERGE REUSE STORAGE');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'INSERT' || '</td>'
            || '<td>' || 'S_GEONAMESMERGE' || '</td>'
            || '<td>' || '' || '</td>';
            
            INSERT
            INTO S_GEONAMESMERGE
            (
                ID,
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                SECOND$COUNTRYSUBDIV_CODE,
                GEONAMESFEATURECLASS_ID,
                GEONAMESFEATURECODE_ID,
                TIMEZONE_ID,
                DATEMODIFIED,
                LATITUDE,
                LONGITUDE,
                NAME,
                NAMEOFFICIAL,
                ELEVATION,
                POPULATION
                --COMMENTS
            )
            --
            SELECT /*+ OPT_ESTIMATE(TABLE A ROWS=9000000) */
            A.GeonamesID AS ID,
            COALESCE
            (
                B.ID,
                (
                    SELECT ID
                    FROM COUNTRY
                    WHERE Name = 'Unknown'
                )
            ) AS Country_ID,
            COALESCE(G.Parent$CountrySubdiv_Code, G.Code) AS CountrySubdiv_Code,
            CASE
                WHEN G.Parent$CountrySubdiv_Code IS NOT NULL THEN G.Code
                ELSE NULL
            END AS Second$CountrySubdiv_Code,
            H.ID AS GeoNamesFeatureClass_ID,
            I.ID AS GeoNamesFeatureCode_ID,
            C.ID AS TimeZone_ID,
            A.ModificationDate AS DateModified,
            A.Latitude,
            A.Longitude,
            CASE
                WHEN TRIM(A.ASCIIName) IS NULL THEN COALESCE
                (
                    TO_ASCII
                    (
                        TRIM(A.Name)
                    ),
                    ' '
                )
                ELSE TRANSLATE
                (
                    TRIM(A.ASCIIName),
                    '‘’`”–',
                    '''''''"-'
                )
            END AS Name,
            TRIM(A.Name) AS NameOfficial,
            CASE
                WHEN COALESCE(A.Elevation, A.DEM) != -9999 THEN COALESCE(A.Elevation, A.DEM)
                ELSE NULL
            END AS Elevation,
            CASE
                WHEN A.Population < 0 THEN NULL
                ELSE A.Population
            END AS Population
            FROM S_GEONAMES A
            LEFT OUTER JOIN COUNTRY B
                ON COALESCE
                        (
                            TRIM
                            (
                                CASE A.CountryCode
                                    --Kosovo still part of Serbia in ISO 3166-2
                                    WHEN 'XK' THEN 'RS'
                                    ELSE A.CountryCode
                                END
                            ),
                            TRIM(A.CC2)
                        )
                        = B.Alpha2
                        AND (TRUNC(SYSDATE) <= B.DateEnd OR B.DateEnd IS NULL)
                        AND (TRUNC(SYSDATE) >= B.DateStart OR B.DateStart IS NULL)
            LEFT OUTER JOIN TIMEZONE C
                ON A.TimeZone = C.Name
            LEFT OUTER JOIN GEONAMESADMINCODE D
                ON A.CountryCode || '.' || A.Admin1Code = D.ID
            LEFT OUTER JOIN GEONAMESADMINCODE E
                ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code = E.ID
            LEFT OUTER JOIN GEONAMESADMINCODE F
                ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code || '.' || A.Admin3Code = F.ID
            LEFT OUTER JOIN COUNTRYSUBDIV G
                ON COALESCE(F.Country_ID, E.Country_ID, D.Country_ID) = G.Country_ID
                        AND COALESCE(F.CountrySubdiv_Code, E.CountrySubdiv_Code, D.CountrySubdiv_Code) = G.Code
            LEFT OUTER JOIN GEONAMESFEATURECLASS H
                ON A.FeatureClass = H.ID
            LEFT OUTER JOIN GEONAMESFEATURECODE I
                ON A.FeatureClass = I.GeoNamesFeatureClass_ID
                        AND A.FeatureCode = I.ID;
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('S_GEONAMESMERGE')
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
            FROM GEONAMES
            WHERE ID NOT IN
            (
                SELECT ID
                FROM S_GEONAMESMERGE
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
            INTO GEONAMES X
            USING 
            (
                SELECT ID,
                Country_ID,
                CountrySubdiv_Code,
                Second$CountrySubdiv_Code,
                GeoNamesFeatureClass_ID,
                GeoNamesFeatureCode_ID,
                TimeZone_ID,
                DateModified,
                SDO_GEOMETRY
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
                ) AS Geometry,
                Name,
                NameOfficial,
                Elevation,
                Population
                FROM
                (
                    SELECT ID,
                    Country_ID,
                    CountrySubdiv_Code,
                    Second$CountrySubdiv_Code,
                    GeoNamesFeatureClass_ID,
                    GeoNamesFeatureCode_ID,
                    TimeZone_ID,
                    DateModified,
                    Latitude,
                    Longitude,
                    Name,
                    NameOfficial,
                    Elevation,
                    Population
                    FROM S_GEONAMESMERGE
                    --
                    MINUS
                    --
                    SELECT A.ID,
                    A.Country_ID,
                    A.CountrySubdiv_Code,
                    A.Second$CountrySubdiv_Code,
                    A.GeoNamesFeatureClass_ID,
                    A.GeoNamesFeatureCode_ID,
                    A.TimeZone_ID,
                    A.DateModified,
                    A.Geometry.SDO_POINT.Y AS Latitude,
                    A.Geometry.SDO_POINT.X AS Longitude,
                    A.Name,
                    A.NameOfficial,
                    A.Elevation,
                    A.Population
                    FROM GEONAMES A
                )
            ) Y
                ON (X.ID = Y.ID)
            WHEN MATCHED THEN UPDATE SET X.Country_ID = Y.Country_ID,
            X.CountrySubdiv_Code = Y.CountrySubdiv_Code,
            X.Second$CountrySubdiv_Code = Y.Second$CountrySubdiv_Code,
            X.GeoNamesFeatureClass_ID = Y.GeoNamesFeatureClass_ID,
            X.GeoNamesFeatureCode_ID = Y.GeoNamesFeatureCode_ID,
            X.TimeZone_ID = Y.TimeZone_ID,
            X.DateModified = Y.DateModified,
            X.Geometry = Y.Geometry,
            X.Name = Y.Name,
            X.NameOfficial = Y.NameOfficial,
            X.Elevation = Y.Elevation,
            X.Population = Y.Population
            WHEN NOT MATCHED THEN INSERT
            (
                ID,
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                SECOND$COUNTRYSUBDIV_CODE,
                GEONAMESFEATURECLASS_ID,
                GEONAMESFEATURECODE_ID,
                TIMEZONE_ID,
                DATEMODIFIED,
                GEOMETRY,
                NAME,
                NAMEOFFICIAL,
                UUID,
                ELEVATION,
                POPULATION
            )
            VALUES
            (
                Y.ID,
                Y.Country_ID,
                Y.CountrySubdiv_Code,
                Y.Second$CountrySubdiv_Code,
                Y.GeoNamesFeatureClass_ID,
                Y.GeoNamesFeatureCode_ID,
                Y.TimeZone_ID,
                Y.DateModified,
                Y.Geometry,
                Y.Name,
                Y.NameOfficial,
                UNCANONICALISE_UUID(UUID_Ver4),
                Y.Elevation,
                Y.Population
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
            
            
            IF gCLOB_Table.Last != 0 THEN
                
                FOR i IN
                gCLOB_Table.First..gCLOB_Table.Last
                LOOP
                    
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
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GEONAMESALTNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            REFRESH_GEONAMESALTNAME
            (
                gFull=>1,
                gDownload=>gDownload
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
            
        ELSE
            
            IF gDownload = 1 THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'INBOUND' || '</td>'
                || '<td>' || 'modifications-' || vDateYesterday || '.txt' || '</td>';
                
                BEGIN
                    
                    nCorrectDownload := 0;
                    
                    WHILE
                    nCorrectDownload = 0
                    LOOP
                        
                        BEGIN
                            
                            SAVE_DATA_FROM_URL(vURLMod || vDateYesterday || '.txt', vTable_Name);
                            
                        --Doesn't matter if the procedure fails, it will be retried
                        EXCEPTION
                        WHEN OTHERS THEN
                            
                            NULL;
                            
                        END;
                        
                        SELECT COUNT(*)
                        INTO nCorrectDownload
                        FROM INBOUND
                        WHERE URL = vURLMod || vDateYesterday || '.txt';
                        
                        IF nCorrectDownload > 0 THEN
                            
                            DELETE
                            FROM INBOUND
                            WHERE (URL, DateTimeX) IN
                            (
                                SELECT URL,
                                DateTimeX
                                FROM INBOUND
                                WHERE URL = vURLMod || vDateYesterday || '.txt'
                                AND UPPER(TRIM(REPLACE(REPLACE(DBMS_LOB.Substr(Data, 1000, 1), CHR(10)), CHR(13)))) LIKE '<!DOCTYPE HTML%'
                            );
                            
                            IF SQL%ROWCOUNT > 0 THEN
                                
                                nCorrectDownload := 0;
                                DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                                
                            ELSE
                                
                                nCorrectDownload := 1;
                                
                            END IF;
                            
                        ELSE
                            
                            DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                            
                        END IF;
                        
                    END LOOP;
                    
                EXCEPTION
                WHEN HANDLED THEN
                    --Propagate the error
                    RAISE HANDLED;
                    
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>' || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'INBOUND' || '</td>'
                || '<td>' || 'deletes-' || vDateYesterday || '.txt' || '</td>';
                
                BEGIN
                    
                    nCorrectDownload := 0;
                    
                    WHILE
                    nCorrectDownload = 0
                    LOOP
                        
                        BEGIN
                            
                            SAVE_DATA_FROM_URL(vURLDel || vDateYesterday || '.txt', vTable_Name);
                            
                        --Doesn't matter if the procedure fails, it will be retried
                        EXCEPTION
                        WHEN OTHERS THEN
                            
                            NULL;
                            
                        END;
                        
                        SELECT COUNT(*)
                        INTO nCorrectDownload
                        FROM INBOUND
                        WHERE URL = vURLDel || vDateYesterday || '.txt';
                        
                        IF nCorrectDownload > 0 THEN
                        
                            DELETE
                            FROM INBOUND
                            WHERE (URL, DateTimeX) IN
                            (
                                SELECT URL,
                                DateTimeX
                                FROM INBOUND
                                WHERE URL = vURLDel || vDateYesterday || '.txt'
                                AND UPPER(TRIM(REPLACE(REPLACE(DBMS_LOB.Substr(Data, 1000, 1), CHR(10)), CHR(13)))) LIKE '<!DOCTYPE HTML%'
                            );
                            
                            IF SQL%ROWCOUNT > 0 THEN
                                
                                nCorrectDownload := 0;
                                DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                                
                            ELSE
                                
                                nCorrectDownload := 1;
                                
                            END IF;
                            
                        ELSE
                            
                            DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                            
                        END IF;
                        
                    END LOOP;        
                    
                EXCEPTION
                WHEN HANDLED THEN
                    --Propagate the error
                    RAISE HANDLED;
                    
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                    || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'INBOUND' || '</td>'
                || '<td>' || 'alternateNamesModifications-' || vDateYesterday || '.txt' || '</td>';
                
                BEGIN
                    
                    nCorrectDownload := 0;
                    
                    WHILE
                    nCorrectDownload = 0
                    LOOP
                        
                        BEGIN
                            
                            SAVE_DATA_FROM_URL(vURLAltMod || vDateYesterday || '.txt', vTable_Name);
                            
                        --Doesn't matter if the procedure fails, it will be retried
                        EXCEPTION
                        WHEN OTHERS THEN
                            
                            NULL;
                            
                        END;
                        
                        SELECT COUNT(*)
                        INTO nCorrectDownload
                        FROM INBOUND
                        WHERE URL = vURLAltMod || vDateYesterday || '.txt';
                        
                        IF nCorrectDownload > 0 THEN
                            
                            DELETE
                            FROM INBOUND
                            WHERE (URL, DateTimeX) IN
                            (
                                SELECT URL,
                                DateTimeX
                                FROM INBOUND
                                WHERE URL = vURLAltMod || vDateYesterday || '.txt'
                                AND UPPER(TRIM(REPLACE(REPLACE(DBMS_LOB.Substr(Data, 1000, 1), CHR(10)), CHR(13)))) LIKE '<!DOCTYPE HTML%'
                            );
                            
                            IF SQL%ROWCOUNT > 0 THEN
                                
                                nCorrectDownload := 0;
                                DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                                
                            ELSE
                                
                                nCorrectDownload := 1;
                                
                            END IF;
                            
                        ELSE
                            
                            DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                            
                        END IF;
                        
                    END LOOP;        
                    
                EXCEPTION
                WHEN HANDLED THEN
                    --Propagate the error
                    RAISE HANDLED;
                    
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                    || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'INBOUND' || '</td>'
                || '<td>' || 'alternateNamesDeletes-' || vDateYesterday || '.txt' || '</td>';
                
                BEGIN
                    
                    nCorrectDownload := 0;
                    
                    WHILE
                    nCorrectDownload = 0
                    LOOP
                        
                        BEGIN
                            
                            SAVE_DATA_FROM_URL(vURLAltDel || vDateYesterday || '.txt', vTable_Name);
                            
                        --Doesn't matter if the procedure fails, it will be retried
                        EXCEPTION
                        WHEN OTHERS THEN
                            
                            NULL;
                            
                        END;
                        
                        SELECT COUNT(*)
                        INTO nCorrectDownload
                        FROM INBOUND
                        WHERE URL = vURLAltDel || vDateYesterday || '.txt';
                        
                        IF nCorrectDownload > 0 THEN
                            
                            DELETE
                            FROM INBOUND
                            WHERE (URL, DateTimeX) IN
                            (
                                SELECT URL,
                                DateTimeX
                                FROM INBOUND
                                WHERE URL = vURLAltDel || vDateYesterday || '.txt'
                                AND UPPER(TRIM(REPLACE(REPLACE(DBMS_LOB.Substr(Data, 1000, 1), CHR(10)), CHR(13)))) LIKE '<!DOCTYPE HTML%'
                            );
                            
                            IF SQL%ROWCOUNT > 0 THEN
                                
                                nCorrectDownload := 0;
                                DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                                
                            ELSE
                                
                                nCorrectDownload := 1;
                                
                            END IF;
                            
                        ELSE
                            
                            DBMS_LOCK.Sleep(10 * 60); --Sleep for 10 minutes
                            
                        END IF;
                        
                    END LOOP;
                    
                EXCEPTION
                WHEN HANDLED THEN
                    --Propagate the error
                    RAISE HANDLED;
                    
                WHEN OTHERS THEN
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                    || '</tr>';
                    
                    RAISE HANDLED;
                    
                END;
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
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
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMES_M' || '</td>'
                || '<td>' || '' || '</td>';
                
                SELECT A.Data
                INTO cCLOB
                FROM INBOUND A
                WHERE A.TableLookup_Name = vTable_Name
                AND A.URL LIKE vURLMod || '%'
                AND A.DateTimeX =
                (
                    SELECT MAX(B.DateTimex)
                    FROM INBOUND B
                    WHERE A.TableLookup_Name = B.TableLookup_Name
                    AND B.URL LIKE vURLMod || '%'
                );
                
                CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMES_M.tsv');
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMES_D' || '</td>'
                || '<td>' || '' || '</td>';
                
                SELECT A.Data
                INTO cCLOB
                FROM INBOUND A
                WHERE A.TableLookup_Name = vTable_Name
                AND A.URL LIKE vURLDel || '%'
                AND A.DateTimeX =
                (
                    SELECT MAX(B.DateTimex)
                    FROM INBOUND B
                    WHERE A.TableLookup_Name = B.TableLookup_Name
                    AND B.URL LIKE vURLDel || '%'
                );
                
                CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMES_D.tsv');
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMESALTNAME_M' || '</td>'
                || '<td>' || '' || '</td>';
                
                SELECT A.Data
                INTO cCLOB
                FROM INBOUND A
                WHERE A.TableLookup_Name = vTable_Name
                AND A.URL LIKE vURLAltMod || '%'
                AND A.DateTimeX =
                (
                    SELECT MAX(B.DateTimex)
                    FROM INBOUND B
                    WHERE A.TableLookup_Name = B.TableLookup_Name
                    AND B.URL LIKE vURLAltMod || '%'
                );
                
                CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESALTNAME_M.tsv');
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'S_GEONAMESALTNAME_D' || '</td>'
                || '<td>' || '' || '</td>';
                
                SELECT A.Data
                INTO cCLOB
                FROM INBOUND A
                WHERE A.TableLookup_Name = vTable_Name
                AND A.URL LIKE vURLAltDel || '%'
                AND A.DateTimeX =
                (
                    SELECT MAX(B.DateTimex)
                    FROM INBOUND B
                    WHERE A.TableLookup_Name = B.TableLookup_Name
                    AND B.URL LIKE vURLAltDel || '%'
                );
                
                CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESALTNAME_D.tsv');
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                || '</tr>';
                
                
                FOR C IN
                (
                    SELECT Table_Name
                    FROM USER_TABLES
                    WHERE Table_Name IN
                    (
                        'S_GEONAMES_D',
                        'S_GEONAMES_M',
                        'S_GEONAMESALTNAME_D',
                        'S_GEONAMESALTNAME_M'
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
                
            END IF; --Ending if set to download
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'MERGE' || '</td>'
            || '<td>' || vTable_Name || '</td>'
            || '<td>' || '' || '</td>';
            
            MERGE
            INTO GEONAMES X
            USING
            (
                SELECT /*+ NOPARALLEL */
                A.GeonamesID AS ID,
                COALESCE
                (
                    B.ID,
                    (
                        SELECT ID
                        FROM COUNTRY
                        WHERE Name = 'Unknown'
                    )
                ) AS Country_ID,
                COALESCE(G.Parent$CountrySubdiv_Code, G.Code) AS CountrySubdiv_Code,
                CASE
                    WHEN G.Parent$CountrySubdiv_Code IS NOT NULL THEN G.Code
                    ELSE NULL
                END AS Second$CountrySubdiv_Code,
                H.ID AS GeoNamesFeatureClass_ID,
                I.ID AS GeoNamesFeatureCode_ID,
                C.ID AS TimeZone_ID,
                A.ModificationDate AS DateModified,
                SDO_GEOMETRY
                (
                    2001,
                    4326, --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                    SDO_POINT_TYPE
                    (
                        A.Longitude,
                        A.Latitude,
                        NULL
                    ),
                    NULL,
                    NULL
                ) AS Geometry,
                CASE
                    WHEN TRIM(A.ASCIIName) IS NULL THEN COALESCE
                    (
                        TO_ASCII
                        (
                            TRIM(A.Name)
                        ),
                        ' '
                    )
                    ELSE TRANSLATE
                    (
                        TRIM(A.ASCIIName),
                        '‘’`”–',
                        '''''''"-'
                    )
                END AS Name,
                TRIM(A.Name) AS NameOfficial,
                CASE
                    WHEN COALESCE(A.Elevation, A.DEM) != -9999 THEN COALESCE(A.Elevation, A.DEM)
                    ELSE NULL
                END AS Elevation,
                CASE
                    WHEN A.Population < 0 THEN NULL
                    ELSE A.Population
                END AS Population
                FROM S_GEONAMES_M A
                LEFT OUTER JOIN COUNTRY B
                    ON COALESCE
                            (
                                TRIM
                                (
                                    CASE A.CountryCode
                                        --Kosovo still part of Serbia in ISO 3166-2
                                        WHEN 'XK' THEN 'RS'
                                        ELSE A.CountryCode
                                    END
                                ),
                                TRIM(A.CC2)
                            )
                            = B.Alpha2
                            AND (TRUNC(SYSDATE) <= B.DateEnd OR B.DateEnd IS NULL)
                            AND (TRUNC(SYSDATE) >= B.DateStart OR B.DateStart IS NULL)
                LEFT OUTER JOIN TIMEZONE C
                    ON A.TimeZone = C.Name
                LEFT OUTER JOIN GEONAMESADMINCODE D
                    ON A.CountryCode || '.' || A.Admin1Code = D.ID
                LEFT OUTER JOIN GEONAMESADMINCODE E
                    ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code = E.ID
                LEFT OUTER JOIN GEONAMESADMINCODE F
                    ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code || '.' || A.Admin3Code = F.ID
                LEFT OUTER JOIN COUNTRYSUBDIV G
                    ON COALESCE(F.Country_ID, E.Country_ID, D.Country_ID) = G.Country_ID
                            AND COALESCE(F.CountrySubdiv_Code, E.CountrySubdiv_Code, D.CountrySubdiv_Code) = G.Code
                LEFT OUTER JOIN GEONAMESFEATURECLASS H
                    ON A.FeatureClass = H.ID
                LEFT OUTER JOIN GEONAMESFEATURECODE I
                    ON A.FeatureClass = I.GeoNamesFeatureClass_ID
                            AND A.FeatureCode = I.ID
            ) Y
                ON (X.ID = Y.ID)
            WHEN MATCHED THEN UPDATE SET X.Country_ID = Y.Country_ID,
            X.CountrySubdiv_Code = Y.CountrySubdiv_Code,
            X.Second$CountrySubdiv_Code = Y.Second$CountrySubdiv_Code,
            X.GeoNamesFeatureClass_ID = Y.GeoNamesFeatureClass_ID,
            X.GeoNamesFeatureCode_ID = Y.GeoNamesFeatureCode_ID,
            X.TimeZone_ID = Y.TimeZone_ID,
            X.DateModified = Y.DateModified,
            X.Geometry = Y.Geometry,
            X.Name = Y.Name,
            X.NameOfficial = Y.NameOfficial,
            X.Elevation = Y.Elevation,
            X.Population = Y.Population
            WHEN NOT MATCHED THEN INSERT
            (
                ID,
                COUNTRY_ID,
                COUNTRYSUBDIV_CODE,
                SECOND$COUNTRYSUBDIV_CODE,
                GEONAMESFEATURECLASS_ID,
                GEONAMESFEATURECODE_ID,
                TIMEZONE_ID,
                DATEMODIFIED,
                GEOMETRY,
                NAME,
                NAMEOFFICIAL,
                UUID,
                ELEVATION,
                POPULATION
                --,COMMENTS
            )
            VALUES
            (
                Y.ID,
                Y.Country_ID,
                Y.CountrySubdiv_Code,
                Y.Second$CountrySubdiv_Code,
                Y.GeoNamesFeatureClass_ID,
                Y.GeoNamesFeatureCode_ID,
                Y.TimeZone_ID,
                Y.DateModified,
                Y.Geometry,
                Y.Name,
                Y.NameOfficial,
                UNCANONICALISE_UUID(UUID_Ver4),
                Y.Elevation,
                Y.Population
            );
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'MERGE' || '</td>'
            || '<td>' || 'GEONAMESALTNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            MERGE
            INTO GEONAMESALTNAME X
            USING
            (
                WITH TMP AS
                (
                    SELECT /*+ MATERIALIZE CARDINALITY(1000) */
                    ID,
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
                            ORDER BY Priority DESC,
                            Preferred DESC NULLS LAST,
                            Short DESC NULLS LAST,
                            URL DESC NULLS LAST,
                            Colloquial DESC NULLS LAST,
                            ID
                        ) AS RN
                        FROM
                        (
                            SELECT A.ID,
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
                            A.URL,
                            0 AS Priority
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
                                FROM S_GEONAMESALTNAME_M
                                WHERE (ISOLanguage != 'post' OR ISOLanguage IS NULL)
                                AND AlternateNameID IS NOT NULL
                                AND GeonameID IS NOT NULL
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
                            --De-duplicate on existing feature names
                            UNION
                            --
                            SELECT ID,
                            GeoNames_ID,
                            Language_ID,
                            Name,
                            Colloquial,
                            Historic,
                            Preferred,
                            Short,
                            URL,
                            1 AS Priority
                            FROM GEONAMESALTNAME
                            WHERE GeoNames_ID IN
                            (
                                SELECT GeoNameID
                                FROM S_GEONAMESALTNAME_M
                                WHERE GeoNameID IS NOT NULL
                            )
                        )
                    )
                    WHERE RN = 1
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
                FROM TMP
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
            WHERE X.GeoNames_ID != Y.GeoNames_ID
            OR X.Language_ID != Y.Language_ID
            OR X.Name != Y.Name
            OR COALESCE(X.Colloquial, '-1') != COALESCE(Y.Colloquial, '-1')
            OR COALESCE(X.Historic, '-1') != COALESCE(Y.Historic, '-1')
            OR COALESCE(X.Preferred, '-1') != COALESCE(Y.Preferred, '-1')
            OR COALESCE(X.Short, '-1') != COALESCE(Y.Short, '-1')
            OR COALESCE(X.URL, '-1') != COALESCE(Y.URL, '-1')
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
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'GEONAMESALTNAME' || '</td>'
            || '<td>' || '' || '</td>';
            
            DELETE
            FROM GEONAMESALTNAME
            WHERE ID IN
            (
                SELECT AlternateNameID
                FROM S_GEONAMESALTNAME_D
                WHERE AlternateNameID IS NOT NULL
            );
            
            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
            || '</tr>';
            
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || vTable_Name || '</td>';
            
            
            FOR C IN
            (
                SELECT COUNT(*) AS Cnt
                FROM S_GEONAMES_D
                WHERE GeoNamesID IS NOT NULL
            ) LOOP
                
                IF C.Cnt = 0 THEN
                    
                    vMsg := vMsg || '<td>' || '' || '</td>'
                    || '<td>' || TO_CHAR(C.Cnt) || '</td>'
                    || '</tr>';
                    
                END IF;
                
            END LOOP;
            
            
            FOR C IN
            (
                SELECT GeoNamesID,
                ROW_NUMBER() OVER (ORDER BY GeoNamesID) AS RN
                FROM S_GEONAMES_D
                WHERE GeoNamesID IS NOT NULL
                ORDER BY GeonamesID
            ) LOOP
                
                IF C.RN = 1 THEN
                    
                    vMsg := vMsg || '<td>' || TO_CHAR(C.GeoNamesID) || '</td>';
                    
                ELSE
                    
                    vMsg := vMsg || CHR(10)
                    || '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'DELETE' || '</td>'
                    || '<td>' || vTable_Name || '</td>'
                    || '<td>' || TO_CHAR(C.GeoNamesID) || '</td>';
                    
                END IF;
                
                BEGIN
                    
                    DELETE
                    FROM GEONAMES
                    WHERE ID = C.GeoNamesID;
                    
                    vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                    || '</tr>';
                    
                EXCEPTION
                WHEN OTHERS THEN 
                    
                    vError := SUBSTRB(SQLErrM, 1, 255);
                    
                    vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
                    || '</tr>';
                    
                    FOR D IN
                    (
                        SELECT Owner,
                        Table_Name,
                        CASE
                            WHEN Nullable = 'Y' THEN 'UPDATE'
                            ELSE 'DELETE'
                        END AS Action
                        FROM ALL_TAB_COLS
                        WHERE (Owner, Table_Name) IN
                        (
                            SELECT Owner,
                            Table_Name
                            FROM ALL_CONSTRAINTS
                            WHERE Constraint_Type = 'R'
                            AND R_Constraint_Name =
                            (
                                SELECT Constraint_Name
                                FROM USER_CONSTRAINTS
                                WHERE Constraint_Type = 'P'
                                AND Table_Name = vTable_Name
                            )
                        )
                        AND Column_Name = 'GEONAMES_ID'
                        ORDER BY Owner,
                        Table_Name
                    ) LOOP
                        
                        BEGIN
                            
                            IF D.Action = 'UPDATE' THEN
                                
                                EXECUTE IMMEDIATE('UPDATE "' || D.Owner || '"."' || D.Table_Name || '" SET GeoNames_ID = NULL WHERE GeoNames_ID = :1') USING C.GeoNamesID;
                                
                            ELSIF D.Action = 'DELETE' THEN
                                
                                IF (D.Owner = 'RD' AND D.Table_Name = 'GEONAMESADMINCODE') THEN
                                    
                                    DELETE
                                    FROM GEONAMESADMINCODE
                                    WHERE Parent$GeoNamesAdminCode_ID =
                                    (
                                        SELECT ID
                                        FROM GEONAMESADMINCODE
                                        WHERE GeoNames_ID = C.GeoNamesID
                                    );
                                    
                                END IF;
                                
                                EXECUTE IMMEDIATE('DELETE FROM "' || D.Owner || '"."' || D.Table_Name || '" WHERE GeoNames_ID = :1') USING C.GeoNamesID;
                                
                            END IF;
                            
                            IF SQL%ROWCOUNT != 0 THEN
                                
                                vMsg := vMsg || CHR(10)
                                || '<tr>'
                                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                                || '<td>' || D.Action || '</td>'
                                || '<td>' || D.Owner || '.' || D.Table_Name || '</td>'
                                || '<td>' || '' || '</td>'
                                || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                                || '</tr>';
                                
                            END IF;
                            
                        EXCEPTION
                        --2013-01-25
                        WHEN DUP_VAL_ON_INDEX THEN
                            
                            vMsg := vMsg || CHR(10)
                            || '<tr>'
                            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                            || '<td>' || 'DELETE' || '</td>'
                            || '<td>' || D.Owner || '.' || D.Table_Name || '</td>'
                            || '<td>' || '' || '</td>';
                            
                            EXECUTE IMMEDIATE('DELETE FROM "' || D.Owner || '"."' || D.Table_Name || '" WHERE GeoNames_ID = :1') USING C.GeoNamesID;
                            
                            vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                            || '</tr>';
                            
                        END;
                        
                    END LOOP;
                    
                    BEGIN
                        
                        vMsg := vMsg || CHR(10)
                        || '<tr>'
                        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                        || '<td>' || 'DELETE' || '</td>'
                        || '<td>' || vTable_Name || '</td>'
                        || '<td>' || C.GeoNamesID || '</td>';
                        
                        DELETE
                        FROM GEONAMES
                        WHERE ID = C.GeoNamesID;
                        
                        IF SQL%ROWCOUNT = 1 THEN
                            
                            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
                            || '</tr>';
                            
                        ELSE
                            
                            vMsg := vMsg || '<td>' || SQL%ROWCOUNT || '</td>'
                            || '</tr>';
                            
                        END IF;
                        
                        vError := ''; --Dealt with this error, hence reset error message
                        
                    EXCEPTION
                    WHEN OTHERS THEN 
                        
                        vError := SUBSTRB(SQLErrM, 1, 255);
                        
                    END;
                    
                END;
                
            END LOOP;
            
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN
                (
                    vTable_Name,
                    'GEONAMESALTNAME'
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
        || '<td>' || 'REFRESH' || '</td>'
        || '<td>' || 'S_TOWNNAME' || '</td>'
        || '<td>' || '' || '</td>';
        
        DBMS_SCHEDULER.Create_Job
        (
            job_name=>'JOB_' || SUBSTRB('REFRESH_S_TOWNNAME', 1, 26), --IN VARCHAR2
            job_type=>'PLSQL_BLOCK', --IN VARCHAR2
            job_action=>'REFRESH_S_TOWNNAME(' || TO_CHAR(gFull) || ');', --IN VARCHAR2
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
        
        
        SELECT COUNT(*)
        INTO nRowsMarketAffected
        FROM MARKET
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
        
        
        IF nRowsMarketAffected > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || vTable_Name || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table(vTable_Name, vGoogleOutput);
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(COALESCE(REPLACE(vGoogleOutput, CHR(10), '<br />'), vError)) || '</td>'
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
        
        
        DBMS_APPLICATION_INFO.Set_Module(NULL, NULL);
        
        
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
        
        DBMS_APPLICATION_INFO.Set_Module(NULL, NULL);
        
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
        
        DBMS_OUTPUT.Put_Line(DBMS_LOB.Substr(vMsg));
        
        DBMS_APPLICATION_INFO.Set_Module(NULL, NULL);
        
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
    
    REFRESH_GEONAMES
    (
        gFull=>1,
        gDownload=>0
    );
    
END;
/

--test changes to code
WITH S_GEONAMES AS
(
    SELECT 2651817 AS GEONAMESID,
    'Croydon' AS NAME,
    'Croydon' AS ASCIINAME,
    51.38333 AS LATITUDE,
    -0.1 AS LONGITUDE,
    'P' AS FEATURECLASS,
    'PPLA3' AS FEATURECODE,
    'GB' AS COUNTRYCODE,
    CAST(NULL AS VARCHAR2(60 BYTE)) AS CC2,
    'ENG' AS ADMIN1CODE,
    'GLA' AS ADMIN2CODE,
    'C8' AS ADMIN3CODE,
    CAST(NULL AS VARCHAR2(20 BYTE)) AS ADMIN4CODE,
    0 AS POPULATION,
    CAST(NULL AS NUMBER) AS ELEVATION,
    54 AS DEM,
    'Europe/London' AS TIMEZONE,
    TO_DATE('2010-10-17', 'YYYY-MM-DD') AS MODIFICATIONDATE
    FROM DUAL
)
--
SELECT A.GeonamesID AS ID,
COALESCE
(
    B.ID,
    (
        SELECT ID
        FROM COUNTRY
        WHERE Name = 'Unknown'
    )
) AS Country_ID,
COALESCE(G.Parent$CountrySubdiv_Code, G.Code) AS CountrySubdiv_Code,
CASE
    WHEN G.Parent$CountrySubdiv_Code IS NOT NULL THEN G.Code
    ELSE NULL
END AS Second$CountrySubdiv_Code,
H.ID AS GeoNamesFeatureClass_ID,
I.ID AS GeoNamesFeatureCode_ID,
C.ID AS TimeZone_ID,
A.ModificationDate AS DateModified,
A.Latitude,
A.Longitude,
CASE
    WHEN TRIM(A.ASCIIName) IS NULL THEN COALESCE
    (
        TO_ASCII
        (
            TRIM(A.Name)
        ),
        ' '
    )
    ELSE TRANSLATE
    (
        TRIM(A.ASCIIName),
        '‘’`”–',
        '''''''"-'
    )
END AS Name,
TRIM(A.Name) AS NameOfficial,
CASE
    WHEN COALESCE(A.Elevation, A.DEM) != -9999 THEN COALESCE(A.Elevation, A.DEM)
    ELSE NULL
END AS Elevation,
CASE
    WHEN A.Population < 0 THEN NULL
    ELSE A.Population
END AS Population
FROM S_GEONAMES A
LEFT OUTER JOIN COUNTRY B
    ON COALESCE
            (
                TRIM
                (
                    CASE A.CountryCode
                        --Kosovo still part of Serbia in ISO 3166-2
                        WHEN 'XK' THEN 'RS'
                        ELSE A.CountryCode
                    END
                ),
                TRIM(A.CC2)
            )
            = B.Alpha2
            AND (TRUNC(SYSDATE) <= B.DateEnd OR B.DateEnd IS NULL)
            AND (TRUNC(SYSDATE) >= B.DateStart OR B.DateStart IS NULL)
LEFT OUTER JOIN TIMEZONE C
    ON A.TimeZone = C.Name
LEFT OUTER JOIN GEONAMESADMINCODE D
    ON A.CountryCode || '.' || A.Admin1Code = D.ID
LEFT OUTER JOIN GEONAMESADMINCODE E
    ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code = E.ID
LEFT OUTER JOIN GEONAMESADMINCODE F
    ON A.CountryCode || '.' || A.Admin1Code || '.' || A.Admin2Code || '.' || A.Admin3Code = F.ID
LEFT OUTER JOIN COUNTRYSUBDIV G
    ON COALESCE(F.Country_ID, E.Country_ID, D.Country_ID) = G.Country_ID
            AND COALESCE(F.CountrySubdiv_Code, E.CountrySubdiv_Code, D.CountrySubdiv_Code) = G.Code
LEFT OUTER JOIN GEONAMESFEATURECLASS H
    ON A.FeatureClass = H.ID
LEFT OUTER JOIN GEONAMESFEATURECODE I
    ON A.FeatureClass = I.GeoNamesFeatureClass_ID
            AND A.FeatureCode = I.ID
ORDER BY ID;
*/