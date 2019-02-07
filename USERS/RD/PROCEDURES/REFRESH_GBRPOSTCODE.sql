SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_GBRPOSTCODE
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'GBRPOSTCODE';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    nDeletes PLS_INTEGER := 0;
    nUnmatchedGBROSGridRefPQI SIMPLE_INTEGER := 0;
    nUnmatchedCountrySubdiv SIMPLE_INTEGER := 0;
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
        
        SELECT COUNT(*)
        INTO nUnmatchedCountrySubdiv
        FROM COUNTRYSUBDIV#GBRONSGEOGCODE
        WHERE GBRONSGeogCode_ID IS NULL;
        
        IF nUnmatchedCountrySubdiv > 0 THEN
            
             vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'COUNTRYSUBDIV#GBRONSGEOGCODE' || '</td>'
            || '<td>' || 'NULL GBRONSGeogCode_ID' || '</td>'
            || '<td>' || TO_CHAR(nUnmatchedCountrySubdiv) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        END IF;
        
        
        SELECT COUNT(*)
        INTO nUnmatchedGBROSGridRefPQI
        FROM
        (
            SELECT OSGrdInd
            FROM S_GBRONSPD
            WHERE OSGrdInd NOT IN
            (
                SELECT ID
                FROM GBROSGRIDREFPQI
            )
            GROUP BY OSGrdInd
        );
        
        IF nUnmatchedGBROSGridRefPQI > 0 THEN
            
             vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'GBROSGRIDREFPQI' || '</td>'
            || '<td>' || 'Missing' || '</td>'
            || '<td>' || TO_CHAR(nUnmatchedGBROSGridRefPQI) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        ELSE
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('GBROSGRIDREFPQI')
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
        || '<td>' || 'TRUNCATE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        EXECUTE IMMEDIATE('TRUNCATE TABLE S_GBRPOSTCODE REUSE STORAGE');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DROP' || '</td>'
        || '<td>' || 'INDEX' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE_GEOMETRY_IX' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('DROP INDEX S_GBRPOSTCODE_GEOMETRY_IX FORCE');
            
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
        || '<td>' || 'DROP' || '</td>'
        || '<td>' || 'CONSTRAINT' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE_PK' || '</td>';
        
        BEGIN
            
            EXECUTE IMMEDIATE('ALTER TABLE S_GBRPOSTCODE DROP PRIMARY KEY DROP INDEX');
            
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
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT /*+ PARALLEL(4) */
        INTO S_GBRPOSTCODE
        (
            POSTCODE,
            COUNTRY_ID,
            COUNTRYSUBDIV_CODE,
            SECOND$COUNTRYSUBDIV_CODE,
            GBRCOUNTYHISTORIC_ID,
            GBRONSGEOGCODE_ID,
            CTYLAUA$GBRONSGEOGCODE_ID,
            NONMETDIS$GBRONSGEOGCODE_ID,
            REGION$GBRONSGEOGCODE_ID,
            GBROSGRIDREFPQI_ID,
            DATESTART,
            POSTCODEEGIF,
            USERLARGE,
            DATEEND,
            GEOMETRY
        )
        --
        SELECT REPLACE(A.Pcd, ' ') AS Postcode,
        CASE
            WHEN B2.Name = 'Isle of Man' THEN 'IMN'
            WHEN A.Pcd LIKE 'GY%' THEN 'GGY'
            WHEN A.Pcd LIKE 'JE%' THEN 'JEY'
            ELSE B.Country_ID
        END AS Country_ID,
        B.CountrySubdiv_Code,
        COALESCE(C.CountrySubdiv_Code, D.CountrySubdiv_Code) AS Second$CountrySubdiv_Code,
        NULL AS GBRCountyHistoric_ID,
        A.Ctry AS GBRONSGeogCode_ID,
        COALESCE(C.GBRONSGeogCode_ID, D.GBRONSGeogCode_ID) AS CtyLAUA$GBRONSGeogCode_ID,
        NULL AS NonMetDis$GBRONSGeogCode_ID,
        E.ID AS Region$GBRONSGeogCode_ID,
        A.OSGrdInd AS GBROSGridRefPQI_ID,
        A.DOIntr AS DateStart,
        CASE
            WHEN INSTRB(A.PcdS, ' ') = 0 THEN SUBSTRB(A.PcdS, 1, LENGTHB(A.PcdS) - 3) || ' ' || SUBSTRB(A.PcdS, -3)
            ELSE A.PcdS
        END AS PostcodeeGIF,
        CASE A.UserType
            WHEN 1 THEN 'T'
            WHEN 0 THEN 'F'
        END AS UserLarge,
        A.DOTerm AS DateEnd,
        CASE
            WHEN (A.Lat IS NOT NULL AND A.Long_ IS NOT NULL)
            --magic values for Lat, Long from page 50 of ONS Postcode Directory User Guide
            AND NOT (A.Long_ = 0 AND A.Lat = 99.999999) THEN SDO_GEOMETRY
            (
                2001,
                --(SELECT SRID FROM MDSYS.CS_SRS WHERE CS_SRS.CS_Name = 'WGS 84' AND Auth_Name LIKE 'EPSG%')
                4326,
                SDO_POINT_TYPE
                (
                    A.Long_,
                    A.Lat,
                    NULL
                ),
                NULL,
                NULL
            )
            ELSE NULL
        END
        /*CASE
            WHEN (A.OSEast1M IS NOT NULL AND A.OSNrth1M IS NOT NULL) THEN SDO_CS.Transform
            (
                SDO_GEOMETRY
                (
                    2001,
                    CASE
                        --TM75 / Irish Grid
                        --ONSPD User Guide February 2017 Section 9
                        WHEN B.CountrySubdiv_Code = 'NIR' THEN 29903
                        --British National Grid
                        --https://www.ordnancesurvey.co.uk/forums/discussion/1001868/correct-oracle-srid
                        ELSE 27700
                    END,
                    SDO_POINT_TYPE
                    (
                        A.OSEast1M,
                        A.OSNrth1M,
                        NULL
                    ),
                    NULL,
                    NULL
                ),
                --WGS 84
                4326
            )
            ELSE NULL
        END*/ AS Geometry
        FROM S_GBRONSPD A
        LEFT OUTER JOIN COUNTRYSUBDIV#GBRONSGEOGCODE B
            ON A.Ctry = B.GBRONSGeogCode_ID
        LEFT OUTER JOIN GBRONSGEOGCODE B2
            ON A.Ctry = B2.ID
        LEFT OUTER JOIN COUNTRYSUBDIV#GBRONSGEOGCODE C
            ON A.OSCty = C.GBRONSGeogCode_ID
        LEFT OUTER JOIN COUNTRYSUBDIV#GBRONSGEOGCODE D
            ON A.OSLAUA = D.GBRONSGeogCode_ID
        LEFT OUTER JOIN GBRONSGEOGCODE G
            ON A.OSLAUA = G.ID
        LEFT OUTER JOIN GBRONSGEOGCODE E
            ON A.Rgn = E.ID
        LEFT OUTER JOIN GBRONSRGC F
            ON E.GBRONSRGC_ID = F.ID
                    AND F.Name = 'Regions';
        --2556015 rows created.
        --Elapsed: 01:33:41.05
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_GBRPOSTCODE')
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
        || '<td>' || 'CREATE' || '</td>'
        || '<td>' || 'INDEX' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE_GEOMETRY_IX' || '</td>';
        
        EXECUTE IMMEDIATE('CREATE INDEX S_GBRPOSTCODE_GEOMETRY_IX ON S_GBRPOSTCODE(Geometry) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2 PARAMETERS (''sdo_max_memory=268435456'') PARALLEL');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'CREATE' || '</td>'
        || '<td>' || 'CONSTRAINT' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE_PK' || '</td>';
        
        EXECUTE IMMEDIATE('ALTER TABLE S_GBRPOSTCODE ADD CONSTRAINT S_GBRPOSTCODE_PK PRIMARY KEY (POSTCODE)');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_GBRPOSTCODE')
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
                ESTIMATE_PERCENT=>1
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'GBRCountyHistoric_ID' || '</td>';
        
        MERGE /*+ USE_HASH(X Y) PARALLEL(4) */
        INTO S_GBRPOSTCODE X
        USING
        (
            SELECT A.Postcode,
            B.GBRCountyHistoric_ID,
            CASE
                WHEN INSTRB(B.Comments, 'GBRCountyHistoric_ID') > 0 THEN B.Comments
                ELSE NULL
            END AS Comments
            FROM S_GBRPOSTCODE A
            INNER JOIN GBRPOSTCODE B
                ON A.Postcode = B.Postcode
                    AND A.Geometry.SDO_POINT.X = COALESCE(B.Geometry.SDO_POINT.X, 0)
                    AND A.Geometry.SDO_POINT.Y = COALESCE(B.Geometry.SDO_POINT.Y, 0)
            WHERE A.GBRCountyHistoric_ID IS NULL
            AND A.Geometry IS NOT NULL
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.GBRCountyHistoric_ID = Y.GBRCountyHistoric_ID,
        X.Comments = CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE X.Comments || CHR(10)
        END
        || Y.Comments;
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'Missing GBRCountyHistoric_ID' || '</td>';
        
        MERGE /*+ USE_HASH(X Y) PARALLEL(4) */
        INTO S_GBRPOSTCODE X
        USING
        (
            SELECT Postcode,
            GBRCountyHistoric_ID
            FROM
            (
                SELECT Postcode,
                GBRCountyHistoric_ID,
                ROW_NUMBER() OVER (PARTITION BY Postcode ORDER BY Priority, Area DESC, GBRCountyHistoric_ID) AS RN
                FROM
                (
                    SELECT A.Postcode,
                    B.ID AS GBRCountyHistoric_ID,
                    0 AS Priority,
                    SDO_GEOM.SDO_Area(B.Geometry, 10000) AS Area
                    FROM S_GBRPOSTCODE A
                    INNER JOIN GBRCOUNTYHISTORIC B
                        ON SDO_INSIDE(A.Geometry, B.Geometry) = 'TRUE'
                    WHERE A.GBRCountyHistoric_ID IS NULL
                    AND A.Geometry IS NOT NULL
                    /*WHERE A.Postcode IN ('SN148AT','SN148AU','SN148AZ','SN148BA','SN148BP','SN148BS','SN148BT','SN148BU','SN148BW','SN148HT','SN148PH','SN148PJ','SN148PL','SN148PN','SN148PP','SN148PR','SN148PS','SN148PT',
                    'SN148PU','SN148PX','SN148PY','SN148PZ','SN148QA','SN148QB','SN148QD','SN148QE','SN148QF','SN148QG','SN148QH','SN148QJ','SN148QL','SN148QN','SN148QP','SN148QQ','SN148QT','SN148QW','SN148QY','SP61PS','SP61PY',
                    'SP61PZ','SP61QA','SP61QB','SP61QD','SP61QE','SP61QF','SP61QG','SP61QQ','SP61RA')*/
                    --
                    /*UNION ALL
                    --The following can't be matched, but have mappings in the ONS site e.g. http://data.ordnancesurvey.co.uk/doc/postcodeunit/DN67EZ
                    --Note that this clause is self-correcting; if proper mapping does occur these will be skipped
                    --Don't try to make this outer join above or an OR; Oracle misbehaves on the spatial join
                    (
                        SELECT 'DN67EZ' AS Postcode, TO_DATE('2013-04-19', 'YYYY-MM-DD') AS DateStart, 'GBR' AS Country_ID, 'WKF' AS Second$CountrySubdiv_Code, 1 AS Priority FROM DUAL
                        UNION ALL
                        SELECT 'NE687SZ' AS Postcode, TO_DATE('2013-04-19', 'YYYY-MM-DD') AS DateStart, 'GBR' AS Country_ID, 'NBL' AS Second$CountrySubdiv_Code, 1 AS Priority FROM DUAL
                        UNION ALL
                        SELECT 'PO332HF' AS Postcode, TO_DATE('2013-04-19', 'YYYY-MM-DD') AS DateStart, 'GBR' AS Country_ID, 'IOW' AS Second$CountrySubdiv_Code, 1 AS Priority FROM DUAL
                    )*/
                )
            )
            WHERE RN = 1
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.GBRCountyHistoric_ID = Y.GBRCountyHistoric_ID;
        --2256894 rows merged.
        --Elapsed: 03:13:02.01
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'Missing GBRCountyHistoric_ID (2)' || '</td>';
        
        MERGE
        INTO S_GBRPOSTCODE X
        USING
        (
            SELECT /*+ OPT_ESTIMATE(TABLE B ROWS=200) INDEX(A GBRCOUNTYHISTORIC_GEOMETRY_IX) INDEX(B S_GBRPOSTCODE_GEOMETRY_IX) */
            B.Postcode,
            A.ID AS GBRCountyHistoric_ID,
            'GBRCountyHistoric_ID calculated as nearest neighbour (' || ROUND(SDO_NN_DISTANCE(1), 0) || ' m away)' AS Comments
            FROM GBRCOUNTYHISTORIC A
            INNER JOIN S_GBRPOSTCODE B
                ON SDO_NN(A.Geometry, B.Geometry, 'sdo_num_res=1', 1) = 'TRUE'
            WHERE B.GBRCountyHistoric_ID IS NULL
            AND B.Geometry IS NOT NULL
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.GBRCountyHistoric_ID = Y.GBRCountyHistoric_ID,
        X.Comments = CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE X.Comments || CHR(10)
        END
        || Y.Comments;
        --213 rows merged.
        --Elapsed: 00:03:03.06
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'NonMetDis$GBRONSGeogCode_ID' || '</td>';
        
        MERGE /*+ USE_HASH(X Y) PARALLEL(4) */
        INTO S_GBRPOSTCODE X
        USING
        (
            SELECT Postcode,
            NonMetDis$GBRONSGeogCode_ID
            FROM
            (
                SELECT Postcode,
                NonMetDis$GBRONSGeogCode_ID,
                ROW_NUMBER() OVER (PARTITION BY Postcode ORDER BY Priority, Area DESC, NonMetDis$GBRONSGeogCode_ID) AS RN
                FROM
                (
                    SELECT /*+ INDEX(A S_GBRPOSTCODE_GEOMETRY_IX) INDEX(B GBRONSGEOGCODE_GEOMETRY_IX) */
                    A.Postcode,
                    B.ID AS NonMetDis$GBRONSGeogCode_ID,
                    0 AS Priority,
                    SDO_GEOM.SDO_Area(B.Geometry, 10000) AS Area
                    FROM S_GBRPOSTCODE A
                    INNER JOIN GBRONSGEOGCODE B
                        ON SDO_INSIDE(A.Geometry, B.Geometry) = 'TRUE'
                    WHERE B.GBRONSRGC_ID =
                    (
                        SELECT ID
                        FROM GBRONSRGC
                        WHERE Name = 'Non-metropolitan Districts'
                    )
                )
            )
            WHERE RN = 1
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.NonMetDis$GBRONSGeogCode_ID = Y.NonMetDis$GBRONSGeogCode_ID;
        --893893 rows merged.
        --Elapsed: 02:17:25.03
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'Missing Region$GBRONSGeogCode_ID' || '</td>';
        
        MERGE
        INTO S_GBRPOSTCODE X
        USING
        (
            WITH SECTOR AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) AS Sector$Postcode,
                CASE
                    WHEN MIN(Region$GBRONSGeogCode_ID) = MAX(Region$GBRONSGeogCode_ID) THEN MIN(Region$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(Region$GBRONSGeogCode_ID)
                END AS Region$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(Region$GBRONSGeogCode_ID) = MAX(Region$GBRONSGeogCode_ID) THEN 'Region$GBRONSGeogCode_ID same as in this postcode sector'
                    WHEN STATS_MODE(Region$GBRONSGeogCode_ID) IS NOT NULL THEN 'Region$GBRONSGeogCode_ID is the mode in this postcode sector'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                WHERE A.Country_ID = 'GBR'
                AND A.CountrySubdiv_Code = 'ENG'
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1)
            ),
            --
            DISTRICT AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) AS District$Postcode,
                CASE
                    WHEN MIN(Region$GBRONSGeogCode_ID) = MAX(Region$GBRONSGeogCode_ID) THEN MIN(Region$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(Region$GBRONSGeogCode_ID)
                END AS Region$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(Region$GBRONSGeogCode_ID) = MAX(Region$GBRONSGeogCode_ID) THEN 'Region$GBRONSGeogCode_ID same as in this postcode district'
                    WHEN STATS_MODE(Region$GBRONSGeogCode_ID) IS NOT NULL THEN 'Region$GBRONSGeogCode_ID is the mode in this postcode district'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                WHERE A.Country_ID = 'GBR'
                AND A.CountrySubdiv_Code = 'ENG'
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1)
            )
            --
            SELECT A.Postcode,
            COALESCE(B.Region$GBRONSGeogCode_ID, C.Region$GBRONSGeogCode_ID) AS Region$GBRONSGeogCode_ID,
            COALESCE(B.Comments, C.Comments) AS Comments
            FROM S_GBRPOSTCODE A
            LEFT OUTER JOIN SECTOR B
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) = B.Sector$Postcode
            LEFT OUTER JOIN DISTRICT C
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) = C.District$Postcode
            WHERE A.Country_ID = 'GBR'
            AND A.CountrySubdiv_Code = 'ENG'
            AND A.Region$GBRONSGeogCode_ID IS NULL
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.Region$GBRONSGeogCode_ID = Y.Region$GBRONSGeogCode_ID,
        X.Comments = CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE X.Comments || CHR(10)
        END
        || Y.Comments;
        --6491 rows merged.
        --Elapsed: 00:03:37.09
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'Missing CtyLAUA$GBRONSGeogCode_ID' || '</td>';
        
        MERGE
        INTO S_GBRPOSTCODE X
        USING
        (
            WITH SECTOR AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) AS Sector$Postcode,
                CASE
                    WHEN MIN(CtyLAUA$GBRONSGeogCode_ID) = MAX(CtyLAUA$GBRONSGeogCode_ID) THEN MIN(CtyLAUA$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(CtyLAUA$GBRONSGeogCode_ID)
                END AS CtyLAUA$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(CtyLAUA$GBRONSGeogCode_ID) = MAX(CtyLAUA$GBRONSGeogCode_ID) THEN 'CtyLAUA$GBRONSGeogCode_ID same as in this postcode sector'
                    WHEN STATS_MODE(CtyLAUA$GBRONSGeogCode_ID) IS NOT NULL THEN 'CtyLAUA$GBRONSGeogCode_ID is the mode in this postcode sector'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                WHERE A.Country_ID = 'GBR'
                AND A.CountrySubdiv_Code = 'ENG'
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1)
            ),
            --
            DISTRICT AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) AS District$Postcode,
                CASE
                    WHEN MIN(CtyLAUA$GBRONSGeogCode_ID) = MAX(CtyLAUA$GBRONSGeogCode_ID) THEN MIN(CtyLAUA$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(CtyLAUA$GBRONSGeogCode_ID)
                END AS CtyLAUA$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(CtyLAUA$GBRONSGeogCode_ID) = MAX(CtyLAUA$GBRONSGeogCode_ID) THEN 'CtyLAUA$GBRONSGeogCode_ID same as in this postcode district'
                    WHEN STATS_MODE(CtyLAUA$GBRONSGeogCode_ID) IS NOT NULL THEN 'CtyLAUA$GBRONSGeogCode_ID is the mode in this postcode district'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                WHERE A.Country_ID = 'GBR'
                AND A.CountrySubdiv_Code = 'ENG'
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1)
            )
            --
            SELECT A.Postcode,
            COALESCE(B.CtyLAUA$GBRONSGeogCode_ID, C.CtyLAUA$GBRONSGeogCode_ID) AS CtyLAUA$GBRONSGeogCode_ID,
            COALESCE(B.Comments, C.Comments) AS Comments
            FROM S_GBRPOSTCODE A
            LEFT OUTER JOIN SECTOR B
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) = B.Sector$Postcode
            LEFT OUTER JOIN DISTRICT C
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) = C.District$Postcode
            WHERE A.Country_ID = 'GBR'
            AND A.CtyLAUA$GBRONSGeogCode_ID IS NULL
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.CtyLAUA$GBRONSGeogCode_ID = Y.CtyLAUA$GBRONSGeogCode_ID,
        X.Comments = CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE X.Comments || CHR(10)
        END
        || Y.Comments;
        --67443 rows merged.
        --Elapsed: 00:01:10.04
        
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_GBRPOSTCODE' || '</td>'
        || '<td>' || 'Missing NonMetDis$GBRONSGeogCode_ID' || '</td>';
        
        MERGE /*+ USE_HASH(X Y) */
        INTO S_GBRPOSTCODE X
        USING
        (
            WITH CTYCTYLAUA#NONMETDIS AS
            (
                SELECT /*+ MATERIALIZE */
                DISTINCT
                C.ID AS CtyLAUA$GBRONSGeogCode_ID
                FROM GBRONSGEOGCODE A
                INNER JOIN GBRONSRGC B
                    ON A.GBRONSRGC_ID = B.ID
                INNER JOIN GBRONSGEOGCODE C
                    ON A.Parent$GBRONSGeogCode_ID = C.ID
                INNER JOIN GBRONSRGC D
                    ON C.GBRONSRGC_ID = D.ID
                WHERE B.Name = 'Non-metropolitan Districts'
            ),
            --
            SECTOR AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) AS Sector$Postcode,
                CASE
                    WHEN MIN(NonMetDis$GBRONSGeogCode_ID) = MAX(NonMetDis$GBRONSGeogCode_ID) THEN MIN(NonMetDis$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(NonMetDis$GBRONSGeogCode_ID)
                END AS NonMetDis$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(NonMetDis$GBRONSGeogCode_ID) = MAX(NonMetDis$GBRONSGeogCode_ID) THEN 'NonMetDis$GBRONSGeogCode_ID same as in this postcode sector'
                    WHEN STATS_MODE(NonMetDis$GBRONSGeogCode_ID) IS NOT NULL THEN 'NonMetDis$GBRONSGeogCode_ID is the mode in this postcode sector'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                INNER JOIN CTYCTYLAUA#NONMETDIS F
                    ON A.CtyLAUA$GBRONSGeogCode_ID = F.CtyLAUA$GBRONSGeogCode_ID
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1)
            ),
            --
            DISTRICT AS
            (
                SELECT SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) AS District$Postcode,
                CASE
                    WHEN MIN(NonMetDis$GBRONSGeogCode_ID) = MAX(NonMetDis$GBRONSGeogCode_ID) THEN MIN(NonMetDis$GBRONSGeogCode_ID)
                    ELSE STATS_MODE(NonMetDis$GBRONSGeogCode_ID)
                END AS NonMetDis$GBRONSGeogCode_ID,
                CASE
                    WHEN MIN(NonMetDis$GBRONSGeogCode_ID) = MAX(NonMetDis$GBRONSGeogCode_ID) THEN 'NonMetDis$GBRONSGeogCode_ID same as in this postcode district'
                    WHEN STATS_MODE(NonMetDis$GBRONSGeogCode_ID) IS NOT NULL THEN 'NonMetDis$GBRONSGeogCode_ID is the mode in this postcode district'
                    ELSE NULL
                END AS Comments
                FROM S_GBRPOSTCODE A
                INNER JOIN CTYCTYLAUA#NONMETDIS F
                    ON A.CtyLAUA$GBRONSGeogCode_ID = F.CtyLAUA$GBRONSGeogCode_ID
                GROUP BY SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1)
            )
            --
            SELECT /* ORDERED */
            A.Postcode,
            COALESCE(B.NonMetDis$GBRONSGeogCode_ID, C.NonMetDis$GBRONSGeogCode_ID) AS NonMetDis$GBRONSGeogCode_ID,
            COALESCE(B.Comments, C.Comments) AS Comments
            FROM S_GBRPOSTCODE A
            INNER JOIN CTYCTYLAUA#NONMETDIS F
                ON A.CtyLAUA$GBRONSGeogCode_ID = F.CtyLAUA$GBRONSGeogCode_ID
            LEFT OUTER JOIN SECTOR B
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') + 1) = B.Sector$Postcode
            LEFT OUTER JOIN DISTRICT C
                ON SUBSTRB(A.PostcodeeGIF, 1, INSTR(A.PostcodeeGIF, ' ') - 1) = C.District$Postcode
            WHERE A.Country_ID = 'GBR'
            AND A.NonMetDis$GBRONSGeogCode_ID IS NULL
        ) Y
            ON (X.Postcode = Y.Postcode)
        WHEN MATCHED THEN UPDATE SET X.NonMetDis$GBRONSGeogCode_ID = Y.NonMetDis$GBRONSGeogCode_ID,
        X.Comments = CASE
            WHEN X.Comments IS NULL THEN NULL
            ELSE X.Comments || CHR(10)
        END
        || Y.Comments;
        --1770 rows merged.
        --Elapsed: 00:00:15.00
        
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
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_GBRPOSTCODE')
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
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE /*+ PARALLEL(4) */
        INTO GBRPOSTCODE X
        USING
        (
            SELECT X.Postcode,
            X.Country_ID,
            X.CountrySubdiv_Code,
            X.Second$CountrySubdiv_Code,
            X.GBRCountyHistoric_ID,
            X.GBRONSGeogCode_ID,
            X.CtyLAUA$GBRONSGeogCode_ID,
            X.NonMetDis$GBRONSGeogCode_ID,
            X.Region$GBRONSGeogCode_ID,
            X.GBROSGridRefPQI_ID,
            X.DateStart,
            X.PostcodeeGIF,
            X.UserLarge,
            CASE
                WHEN X.DateStart = X.DateEnd THEN X.DateEnd + INTERVAL '1' DAY
                ELSE X.DateEnd
            END AS DateEnd,
            X.Geometry,
            X.Comments
            FROM S_GBRPOSTCODE X
            LEFT OUTER JOIN GBRPOSTCODE Y
                ON X.Postcode = Y.Postcode
            WHERE Y.Postcode IS NULL
            OR X.Country_ID != Y.Country_ID
            OR COALESCE(X.CountrySubdiv_Code,'-1') != COALESCE(Y.CountrySubdiv_Code,'-1')
            OR COALESCE(X.Second$CountrySubdiv_Code,'-1') != COALESCE(Y.Second$CountrySubdiv_Code,'-1')
            OR COALESCE(X.GBRCountyHistoric_ID,'-1') != COALESCE(Y.GBRCountyHistoric_ID,'-1')
            OR COALESCE(X.GBRONSGeogCode_ID,'-1') != COALESCE(Y.GBRONSGeogCode_ID,'-1')
            OR COALESCE(X.CtyLAUA$GBRONSGeogCode_ID,'-1') != COALESCE(Y.CtyLAUA$GBRONSGeogCode_ID,'-1')
            OR COALESCE(X.NonMetDis$GBRONSGeogCode_ID,'-1') != COALESCE(Y.NonMetDis$GBRONSGeogCode_ID,'-1')
            OR COALESCE(X.Region$GBRONSGeogCode_ID,'-1') != COALESCE(Y.Region$GBRONSGeogCode_ID,'-1')
            OR X.GBROSGridRefPQI_ID != Y.GBROSGridRefPQI_ID
            OR X.DateStart != Y.DateStart
            OR X.PostcodeeGIF != Y.PostcodeeGIF
            OR X.UserLarge != Y.UserLarge
            OR COALESCE
            (
                CASE
                    WHEN X.DateStart = X.DateEnd THEN X.DateEnd + INTERVAL '1' DAY
                    ELSE X.DateEnd
                END,
                TO_DATE('00010101', 'YYYYMMDD')
            ) != COALESCE(Y.DateEnd, TO_DATE('00010101', 'YYYYMMDD'))
            OR COALESCE(X.Geometry.SDO_POINT.X, 0) != COALESCE(Y.Geometry.SDO_POINT.X, 0)
            OR COALESCE(X.Geometry.SDO_POINT.Y, 0) != COALESCE(Y.Geometry.SDO_POINT.Y, 0)
            OR COALESCE(X.Comments,'-1') != COALESCE(Y.Comments,'-1')
        ) Y
            ON (X.POSTCODE = Y.POSTCODE)
        WHEN MATCHED THEN UPDATE SET X.COUNTRY_ID = Y.COUNTRY_ID,
        X.COUNTRYSUBDIV_CODE = Y.COUNTRYSUBDIV_CODE,
        X.SECOND$COUNTRYSUBDIV_CODE = Y.SECOND$COUNTRYSUBDIV_CODE,
        X.GBRCOUNTYHISTORIC_ID = Y.GBRCOUNTYHISTORIC_ID,
        X.GBRONSGEOGCODE_ID = Y.GBRONSGEOGCODE_ID,
        X.CTYLAUA$GBRONSGEOGCODE_ID = Y.CTYLAUA$GBRONSGEOGCODE_ID,
        X.NONMETDIS$GBRONSGEOGCODE_ID = Y.NONMETDIS$GBRONSGEOGCODE_ID,
        X.REGION$GBRONSGEOGCODE_ID = Y.REGION$GBRONSGEOGCODE_ID,
        X.GBROSGRIDREFPQI_ID = Y.GBROSGRIDREFPQI_ID,
        X.DATESTART = Y.DATESTART,
        X.POSTCODEEGIF = Y.POSTCODEEGIF,
        X.USERLARGE = Y.USERLARGE,
        X.DATEEND = Y.DATEEND,
        X.GEOMETRY = Y.GEOMETRY,
        X.COMMENTS = Y.COMMENTS
        WHEN NOT MATCHED THEN INSERT
        (
            POSTCODE,
            COUNTRY_ID,
            COUNTRYSUBDIV_CODE,
            SECOND$COUNTRYSUBDIV_CODE,
            GBRCOUNTYHISTORIC_ID,
            GBRONSGEOGCODE_ID,
            CTYLAUA$GBRONSGEOGCODE_ID,
            NONMETDIS$GBRONSGEOGCODE_ID,
            REGION$GBRONSGEOGCODE_ID,
            GBROSGRIDREFPQI_ID,
            DATESTART,
            POSTCODEEGIF,
            USERLARGE,
            DATEEND,
            GEOMETRY,
            COMMENTS
        )
        VALUES
        (
            Y.POSTCODE,
            Y.COUNTRY_ID,
            Y.COUNTRYSUBDIV_CODE,
            Y.SECOND$COUNTRYSUBDIV_CODE,
            Y.GBRCOUNTYHISTORIC_ID,
            Y.GBRONSGEOGCODE_ID,
            Y.CTYLAUA$GBRONSGEOGCODE_ID,
            Y.NONMETDIS$GBRONSGEOGCODE_ID,
            Y.REGION$GBRONSGEOGCODE_ID,
            Y.GBROSGRIDREFPQI_ID,
            Y.DATESTART,
            Y.POSTCODEEGIF,
            Y.USERLARGE,
            Y.DATEEND,
            Y.GEOMETRY,
            Y.COMMENTS
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
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
            DBMS_LOB.Substr(vMsg)
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
    
    REFRESH_GBRPOSTCODE;
    
END;
/

--fix missing COUNTRYSUBDIV#GBRONSGEOGCODE mappings
merge
into GBRPOSTCODE X
using
(
    with STAGING AS
    (
        select /*+ MATERIALIZE */ /*
        FROM COUNTRYSUBDIV#GBRONSGEOGCODE
        where GBRONSGeogCode_ID LIKE 'N%'
    )
    --
    select REPLACE(A.Pcd, ' ') AS Postcode,
    COALESCE(C.CountrySubdiv_Code, D.CountrySubdiv_Code) AS Second$CountrySubdiv_Code
    from S_Gbronspd a
    LEFT OUTER JOIN STAGING C
                ON A.OSCty = C.GBRONSGeogCode_ID
            LEFT OUTER JOIN STAGING D
                ON A.OSLAUA = D.GBRONSGeogCode_ID
    where COALESCE(C.CountrySubdiv_Code, D.CountrySubdiv_Code) IS NOT NULL
) y
    on (x.postcode = y.postcode)
when matched then update set X.Second$CountrySubdiv_Code = Y.Second$CountrySubdiv_Code;
*/