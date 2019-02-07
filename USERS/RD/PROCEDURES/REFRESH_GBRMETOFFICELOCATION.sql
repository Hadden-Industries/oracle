SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GBRMETOFFICELOCATION
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'GBRMETOFFICELOCATION ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nDeletes SIMPLE_INTEGER := 0;
    bExists BOOLEAN := FALSE;
    nRowsDeleted SIMPLE_INTEGER := 0;
    nUpdated SIMPLE_INTEGER := 0;
    vURL VARCHAR2(4000 BYTE) := 'http://datapoint.metoffice.gov.uk/public/data/val/wxfcs/all/json/sitelist?key=';
    vAPIKey VARCHAR2(36 BYTE) := GET_API_KEY('Met Office');
    
    --Document formatting variable
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
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL || vAPIKey, 'GBRMETOFFICELOCATION');
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        END;
        
        
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
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL || vAPIKey);
        
        nDeletes := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF nDeletes > 0 THEN --Nothing to update, so exit
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('GBRMETOFFICELOCATION')
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
            
            
            RAISE HANDLED;
            
            
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
        
        
        FOR B IN
        (
            SELECT ID
            FROM GBRMETOFFICELOCATION
            WHERE ID NOT IN
            (
                SELECT ID
                FROM JSON_TABLE
                (
                    (
                        SELECT Data
                        FROM LATEST$INBOUND
                        WHERE TableLookup_Name = 'GBRMETOFFICELOCATION'
                    ),
                    '$.Locations.Location[*]' COLUMNS
                    (
                        id INTEGER PATH '$.id'
                    )
                )
            )
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'GBRMETOFFICELOCATION' || '</td>'
            || '<td>' || TO_CHAR(B.ID) || '</td>';
            
            DELETE
            FROM GBRMETOFFICELOCATION
            WHERE ID = B.ID;
            
            nRowsDeleted := nRowsDeleted + SQL%ROWCOUNT;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT ID,
            Longitude,
            Latitude,
            Name,
            Elevation,
            ObsSource,
            NationalPark,
            Region,
            UnitaryAuthArea
            FROM JSON_TABLE
            (
                (
                    SELECT Data
                    FROM LATEST$INBOUND
                    WHERE TableLookup_Name = 'GBRMETOFFICELOCATION'
                ),
                '$.Locations.Location[*]' COLUMNS
                (
                    elevation NUMBER PATH '$.elevation',
                    id INTEGER PATH '$.id',
                    latitude NUMBER PATH '$.latitude',
                    longitude NUMBER PATH '$.longitude',
                    obsSource VARCHAR2(100 BYTE) PATH '$.obsSource',
                    name VARCHAR2(100 BYTE) PATH '$.name',
                    nationalPark VARCHAR2(100 BYTE) PATH '$.nationalPark',
                    region VARCHAR2(2 BYTE) PATH '$.region',
                    unitaryAuthArea VARCHAR2(100 BYTE) PATH '$.unitaryAuthArea'
                )
            )
            --
            MINUS
            --
            SELECT ID,
            A.Geometry.SDO_POINT.X AS Longitude,
            A.Geometry.SDO_POINT.Y AS Latitude,
            Name,
            Elevation,
            ObsSource,
            NationalPark,
            Region,
            UnitaryAuthArea
            FROM GBRMETOFFICELOCATION A
            ORDER BY 1
        ) LOOP
            
            
            bExists := FALSE;
            
            
            FOR D IN
            (
                SELECT ID,
                A.Geometry.SDO_POINT.X AS Longitude,
                A.Geometry.SDO_POINT.Y AS Latitude,
                Name,
                Elevation,
                ObsSource,
                NationalPark,
                Region,
                UnitaryAuthArea
                FROM GBRMETOFFICELOCATION A
                WHERE A.ID = C.ID
            ) LOOP
                
                
                bExists := TRUE;
                
                
                IF C.Longitude != D.Longitude OR C.Latitude != D.Latitude THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.Geometry' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET Geometry = SDO_GEOMETRY
                    (
                        2001,
                        --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                        4326,
                        SDO_POINT_TYPE
                        (
                            C.Longitude,
                            C.Latitude,
                            NULL
                        ),
                        NULL,
                        NULL
                    )
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || '{' || TO_CHAR(D.Longitude) || ',' || TO_CHAR(D.Latitude) || '}' || '=>' || '{' || TO_CHAR(C.Longitude) || ',' || TO_CHAR(C.Latitude) || '}' || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Name != D.Name THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.Name' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET Name = C.Name
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Name || '=>' || C.Name || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Elevation, -1) != COALESCE(D.Elevation, -1) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.Elevation' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET Elevation = C.Elevation
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Elevation || '=>' || C.Elevation || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.ObsSource, CHR(0)) != COALESCE(D.ObsSource, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.ObsSource' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET ObsSource = C.ObsSource
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.ObsSource || '=>' || C.ObsSource || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.NationalPark, CHR(0)) != COALESCE(D.NationalPark, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.NationalPark' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET NationalPark = C.NationalPark
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.NationalPark || '=>' || C.NationalPark || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Region, CHR(0)) != COALESCE(D.Region, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.Region' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET Region = C.Region
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Region || '=>' || C.Region || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.UnitaryAuthArea, CHR(0)) != COALESCE(D.UnitaryAuthArea, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.UnitaryAuthArea' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET UnitaryAuthArea = C.UnitaryAuthArea
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.UnitaryAuthArea || '=>' || C.UnitaryAuthArea || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                /*IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'GBRMETOFFICELOCATION.Comments' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    GBRMETOFFICELOCATION
                    SET Comments = C.Comments
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Comments || '=>' || C.Comments || ')' || '</td>'
                    || '</tr>';
                    
                END IF;*/
                
                
            END LOOP;
            
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'GBRMETOFFICELOCATION' || '</td>'
                || '<td>' || C.ID || ','
                || '{' || TO_CHAR(C.Longitude) || ',' || TO_CHAR(C.Latitude) || '}' || ','
                || TEXT_TO_HTML(C.Name) || ','
                || TO_CHAR(C.Elevation) || ','
                || TEXT_TO_HTML(C.ObsSource) || ','
                || TEXT_TO_HTML(C.NationalPark) || ','
                || TEXT_TO_HTML(C.Region) || ','
                || TEXT_TO_HTML(C.UnitaryAuthArea) || '</td>';
                
                INSERT
                INTO GBRMETOFFICELOCATION
                (
                    ID,
                    GEOMETRY,
                    NAME,
                    ELEVATION,
                    OBSSOURCE,
                    NATIONALPARK,
                    REGION,
                    UNITARYAUTHAREA--,
                    --COMMENTS
                )
                VALUES
                (
                    C.ID,
                    SDO_GEOMETRY
                    (
                        2001,
                        --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                        4326,
                        SDO_POINT_TYPE
                        (
                            C.Longitude,
                            C.Latitude,
                            NULL
                        ),
                        NULL,
                        NULL
                    ),
                    C.Name,
                    C.Elevation,
                    C.ObsSource,
                    C.NationalPark,
                    C.Region,
                    C.UnitaryAuthArea
                );
                
                nUpdated := nUpdated + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('GBRMETOFFICELOCATION')
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
            WHERE Table_Name IN ('GBRMETOFFICELOCATION')
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
                ownname=>NULL,
                tabname=>C.Table_Name,
                method_opt=>'FOR ALL COLUMNS SIZE SKEWONLY',
                cascade=>TRUE,
                estimate_percent=>100
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
    
    REFRESH_GBRMETOFFICELOCATION;
    
END;
/
*/