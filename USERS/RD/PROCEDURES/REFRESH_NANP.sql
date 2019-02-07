SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_NANP
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'NANP ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    vURL VARCHAR2(4000 BYTE) := 'https://nationalnanpa.com/nanp1/npa_report.csv';
    cCLOB CLOB := EMPTY_CLOB();
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    nDeletes PLS_INTEGER := 0;
    nUnhandledCountrySubdivs PLS_INTEGER := 0;
    nRowsNANP PLS_INTEGER := 0;
    nRowsCOUNTRYSUBDIV#NANP PLS_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        BEGIN
            
            SAVE_DATA_FROM_URL(vURL, 'NANP');
            
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
        
        
        vMsg := vMsg || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'INBOUND' || '</td>'
        || '<td>' || TEXT_TO_HTML(vURL) || '</td>';
        
        DELETE_INBOUND_DUPLICATE(vURL);
        
        nDeletes := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        IF nDeletes > 0 THEN --Nothing to update, so exit
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN
                (
                    'COUNTRYSUBDIV#NANP',
                    'NANP',
                    'S_NANP'
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
            
            
            RAISE HANDLED;
            
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'TRUNCATE' || '</td>'
        || '<td>' || 'S_NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            UTL_FILE.FRemove('RD', 'S_NANP.csv');
            
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
        || '<td>' || 'S_NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        SELECT A.Data
        INTO cCLOB
        FROM LATEST$INBOUND A
        WHERE A.TableLookup_Name = 'NANP'
        AND A.URL = vURL;
        
        CLOB_TO_FILE(cCLOB, 'RD', 'S_NANP.csv');
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_NANP')
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
        || '<td>' || 'NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        BEGIN
            
            DELETE
            FROM NANP
            WHERE ID IN
            (
                SELECT ID
                FROM
                (
                    SELECT ID
                    FROM NANP
                    --
                    MINUS
                    --
                    SELECT ID
                    FROM S_NANP
                )
            );
            
            nRowsNANP := SQL%ROWCOUNT;
            
        EXCEPTION
        WHEN OTHERS THEN
            
            vError := SUBSTRB(SQLErrM, 1, 255);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
            || '</tr>';
            
        END;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE
        INTO NANP X
        USING
        (
            SELECT ID,
            Parent_NANP_ID AS Parent$NANP_ID,
            CASE Assignable
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS Assignable,
            CASE Assigned
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS Assigned,
            CASE EasilyRecognisable
                WHEN 'Easily Recognizable Code' THEN 'T'
                ELSE 'F'
            END AS EasilyRecognisable,
            CASE InService
                WHEN 'Y' THEN 'T'
                WHEN 'Yes' THEN 'T'
                WHEN 'N' THEN 'F'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS InService,
            CASE ReliefPlanningInProgress
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS ReliefPlanningInProgress,
            CASE Reserved
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS Reserved,
            AssignableExplanation,
            AssignedService,
            CASE
                --INTERVAL can only be two characters long
                WHEN AssignedDate > SYSDATE THEN AssignedDate - INTERVAL '50' YEAR - INTERVAL '50' YEAR
                ELSE AssignedDate
            END AS DateAssigned,
            CASE
                --INTERVAL can only be two characters long
                WHEN InServiceDate > SYSDATE THEN InServiceDate - INTERVAL '50' YEAR - INTERVAL '50' YEAR
                ELSE InServiceDate
            END AS DateInService,
            ForeignToLocal,
            ForeignToLocalPerm,
            ForeignToToll,
            CASE Geographic
                WHEN 'G' THEN 'T'
                WHEN 'N' THEN 'F'
                ELSE NULL
            END AS Geographic,
            HomeToLocal,
            HomeToLocalPerm,
            HomeToToll,
            HomeToTollPerm,
            CASE Jeopardy
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS Jeopardy,
            Map,
            CASE Overlay
                WHEN 'Yes' THEN 'T'
                WHEN 'No' THEN 'F'
                ELSE NULL
            END AS Overlay,
            OverlayComplex,
            PlanningLetterNumbers,
            CASE Status
                WHEN 'Active' THEN 'A'
                WHEN 'Postponed' THEN 'P'
                WHEN 'Suspended' THEN 'S'
                ELSE NULL
            END AS Status,
            Comments
            FROM S_NANP
            --
            MINUS
            --
            SELECT ID, 
            Parent$NANP_ID, 
            Assignable, 
            Assigned, 
            EasilyRecognisable, 
            InService, 
            ReliefPlanningInProgress, 
            Reserved, 
            AssignableExplanation, 
            AssignedService, 
            DateAssigned, 
            DateInService, 
            ForeignToLocal, 
            ForeignToLocalPerm, 
            ForeignToToll, 
            Geographic, 
            HomeToLocal, 
            HomeToLocalPerm, 
            HomeToToll, 
            HomeToTollPerm, 
            Jeopardy, 
            Map, 
            Overlay, 
            OverlayComplex, 
            PlanningLetterNumbers, 
            Status, 
            Comments
            FROM NANP
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Parent$NANP_ID = Y.Parent$NANP_ID
        , X.Assignable = Y.Assignable
        , X.Assigned = Y.Assigned
        , X.EasilyRecognisable = Y.EasilyRecognisable
        , X.InService = Y.InService
        , X.ReliefPlanningInProgress = Y.ReliefPlanningInProgress
        , X.Reserved = Y.Reserved
        , X.AssignableExplanation = Y.AssignableExplanation
        , X.AssignedService = Y.AssignedService
        , X.DateAssigned = Y.DateAssigned
        , X.DateInService = Y.DateInService
        , X.ForeignToLocal = Y.ForeignToLocal
        , X.ForeignToLocalPerm = Y.ForeignToLocalPerm
        , X.ForeignToToll = Y.ForeignToToll
        , X.Geographic = Y.Geographic
        , X.HomeToLocal = Y.HomeToLocal
        , X.HomeToLocalPerm = Y.HomeToLocalPerm
        , X.HomeToToll = Y.HomeToToll
        , X.HomeToTollPerm = Y.HomeToTollPerm
        , X.Jeopardy = Y.Jeopardy
        , X.Map = Y.Map
        , X.Overlay = Y.Overlay
        , X.OverlayComplex = Y.OverlayComplex
        , X.PlanningLetterNumbers = Y.PlanningLetterNumbers
        , X.Status = Y.Status
        , X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (ID
        , PARENT$NANP_ID
        , ASSIGNABLE
        , ASSIGNED
        , EASILYRECOGNISABLE
        , INSERVICE
        , RELIEFPLANNINGINPROGRESS
        , RESERVED
        , ASSIGNABLEEXPLANATION
        , ASSIGNEDSERVICE
        , DATEASSIGNED
        , DATEINSERVICE
        , FOREIGNTOLOCAL
        , FOREIGNTOLOCALPERM
        , FOREIGNTOTOLL
        , GEOGRAPHIC
        , HOMETOLOCAL
        , HOMETOLOCALPERM
        , HOMETOTOLL
        , HOMETOTOLLPERM
        , JEOPARDY
        , MAP
        , OVERLAY
        , OVERLAYCOMPLEX
        , PLANNINGLETTERNUMBERS
        , STATUS
        , COMMENTS)
        VALUES
        (Y.ID
        , Y.Parent$NANP_ID
        , Y.Assignable
        , Y.Assigned
        , Y.EasilyRecognisable
        , Y.InService
        , Y.ReliefPlanningInProgress
        , Y.Reserved
        , Y.AssignableExplanation
        , Y.AssignedService
        , Y.DateAssigned
        , Y.DateInService
        , Y.ForeignToLocal
        , Y.ForeignToLocalPerm
        , Y.ForeignToToll
        , Y.Geographic
        , Y.HomeToLocal
        , Y.HomeToLocalPerm
        , Y.HomeToToll
        , Y.HomeToTollPerm
        , Y.Jeopardy
        , Y.Map
        , Y.Overlay
        , Y.OverlayComplex
        , Y.PlanningLetterNumbers
        , Y.Status
        , Y.Comments);
        
        nRowsNANP := nRowsNANP + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('NANP')
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
                'NANP'
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
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'CHECK' || '</td>'
        || '<td>' || 'COUNTRYSUBDIV#NANP' || '</td>'
        || '<td>' || 'Unhandled CountrySubdivs' || '</td>';
        
        WITH S_COUNTRYSUBDIV#NANP AS
        (
            SELECT ID,
            Country_Name,
            CountrySubdiv_Name
            FROM S_NANP
        )
        --
        SELECT COUNT(*)
        INTO nUnhandledCountrySubdivs
        FROM
        (
            SELECT A.ID,
            B.Country_ID,
            A.CountrySubdiv_Name
            FROM S_COUNTRYSUBDIV#NANP A
            LEFT OUTER JOIN UNIQUE$COUNTRYNAME B
                ON TRIM
                        (
                            REGEXP_REPLACE
                            (
                                REGEXP_REPLACE
                                (
                                    UPPER(A.Country_Name),
                                    '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                    ''
                                ),
                                '[[:blank:]]{2,}',
                                ' '
                            )
                        ) = B.Name
        )
        WHERE (INSTR(CountrySubdiv_Name, '-') <> 0 OR INSTR(CountrySubdiv_Name, ',') <> 0)
        AND CountrySubdiv_Name NOT IN ('NOVA SCOTIA - PRINCE EDWARD ISLAND', 'YUKON-NW TERR. - NUNAVUT');
        
        vMsg := vMsg || '<td>' || TO_CHAR(nUnhandledCountrySubdivs) || '</td>'
        || '</tr>';
        
        
        IF nUnhandledCountrySubdivs > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'DELETE' || '</td>'
        || '<td>' || 'COUNTRYSUBDIV#NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        DELETE
        FROM COUNTRYSUBDIV#NANP
        WHERE
        (
            Country_ID,
            NANP_ID,
            COALESCE(CountrySubdiv_Code, CHR(0))
        )
        IN
        (
            WITH S_COUNTRYSUBDIV#NANP
            AS
            (
                SELECT ID,
                Country_Name,
                CountrySubdiv_Name
                FROM S_NANP
            ),
            --
            S_COUNTRYSUBDIV#NANP2
            AS
            (
                SELECT A.Country_ID,
                A.ID AS NANP_ID,
                B.Code AS CountrySubdiv_Code
                FROM
                (
                    SELECT A.ID,
                    B.Country_ID,
                    A.CountrySubdiv_Name
                    FROM S_COUNTRYSUBDIV#NANP A
                    LEFT OUTER JOIN UNIQUE$COUNTRYNAME B
                        ON TRIM
                                (
                                    REGEXP_REPLACE
                                    (
                                        REGEXP_REPLACE
                                        (
                                            UPPER(A.Country_Name),
                                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                            ''
                                        ),
                                        '[[:blank:]]{2,}',
                                        ' '
                                    )
                                ) = B.Name
                    --
                    UNION ALL
                    --
                    SELECT 782 AS ID, 'CAN' AS Country_ID, 'Nova Scotia' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 782 AS ID, 'CAN' AS Country_ID, 'Prince Edward Island' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 867 AS ID, 'CAN' AS Country_ID, 'Yukon Territory' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 867 AS ID, 'CAN' AS Country_ID, 'Northwest Territories' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 867 AS ID, 'CAN' AS Country_ID, 'Nunavut' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 902 AS ID, 'CAN' AS Country_ID, 'Nova Scotia' AS CountrySubdiv_Name FROM DUAL
                    --
                    UNION ALL
                    --
                    SELECT 902 AS ID, 'CAN' AS Country_ID, 'Prince Edward Island' AS CountrySubdiv_Name FROM DUAL
                ) A
                LEFT OUTER JOIN COUNTRYSUBDIV B
                    ON A.Country_ID = B.Country_ID
                            AND CASE
                                WHEN A.Country_ID = 'CAN' AND UPPER(A.CountrySubdiv_Name) = 'NEWFOUNDLAND' THEN UPPER('Newfoundland and Labrador')
                                WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'CNMI' THEN 'MP'
                                WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'USVI' THEN 'VI'
                                WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'PUERTO RICO' THEN 'PR'
                                ELSE UPPER(A.CountrySubdiv_Name)
                            END
                            =
                            CASE
                                WHEN A.Country_ID = 'USA' THEN B.Code
                                ELSE UPPER(B.Name)
                            END
                WHERE A.Country_ID IS NOT NULL
                AND
                (
                    NOT (INSTR(A.CountrySubdiv_Name, '-') <> 0)
                    OR A.CountrySubdiv_Name IS NULL
                )
            )
            --
            SELECT Country_ID,
            NANP_ID,
            COALESCE(CountrySubdiv_Code, CHR(0)) AS CountrySubdiv_Code
            FROM
            (
                SELECT Country_ID,
                NANP_ID,
                CountrySubdiv_Code
                FROM COUNTRYSUBDIV#NANP
                --
                MINUS
                --
                SELECT Country_ID,
                NANP_ID,
                CountrySubdiv_Code
                FROM
                (
                    SELECT Country_ID,
                    NANP_ID,
                    CountrySubdiv_Code
                    FROM S_COUNTRYSUBDIV#NANP2
                    --
                    UNION ALL
                    --
                    SELECT B.ID AS Country_ID,
                    A.NANP_ID,
                    NULL AS CountrySubdiv_Code
                    FROM S_COUNTRYSUBDIV#NANP2 A
                    INNER JOIN COUNTRY B
                        ON A.Country_ID = B.Parent$Country_ID
                                AND A.CountrySubdiv_Code = B.Alpha2
                    WHERE (TRUNC(SYSDATE) >= B.DateStart OR B.DateStart IS NULL)
                    AND (TRUNC(SYSDATE) <= B.DateEnd OR B.DateEnd IS NULL)
                )
            )
        );
        
        nRowsCOUNTRYSUBDIV#NANP := SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'INSERT' || '</td>'
        || '<td>' || 'COUNTRYSUBDIV#NANP' || '</td>'
        || '<td>' || '' || '</td>';
        
        INSERT
        INTO COUNTRYSUBDIV#NANP
        (
            COUNTRY_ID,
            NANP_ID,
            COUNTRYSUBDIV_CODE
        )
        --
        WITH S_COUNTRYSUBDIV#NANP
        AS
        (
            SELECT ID,
            Country_Name,
            CountrySubdiv_Name
            FROM S_NANP
        ),
        --
        S_COUNTRYSUBDIV#NANP2
        AS
        (
            SELECT A.Country_ID,
            A.ID AS NANP_ID,
            B.Code AS CountrySubdiv_Code
            FROM
            (
                SELECT A.ID,
                B.Country_ID,
                A.CountrySubdiv_Name
                FROM S_COUNTRYSUBDIV#NANP A
               LEFT OUTER JOIN UNIQUE$COUNTRYNAME B
                        ON TRIM
                                (
                                    REGEXP_REPLACE
                                    (
                                        REGEXP_REPLACE
                                        (
                                            UPPER(A.Country_Name),
                                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                            ''
                                        ),
                                        '[[:blank:]]{2,}',
                                        ' '
                                    )
                                ) = B.Name
                --
                UNION ALL
                --
                SELECT 782 AS ID, 'CAN' AS Country_ID, 'Nova Scotia' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 782 AS ID, 'CAN' AS Country_ID, 'Prince Edward Island' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 867 AS ID, 'CAN' AS Country_ID, 'Yukon Territory' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 867 AS ID, 'CAN' AS Country_ID, 'Northwest Territories' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 867 AS ID, 'CAN' AS Country_ID, 'Nunavut' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 902 AS ID, 'CAN' AS Country_ID, 'Nova Scotia' AS CountrySubdiv_Name FROM DUAL
                --
                UNION ALL
                --
                SELECT 902 AS ID, 'CAN' AS Country_ID, 'Prince Edward Island' AS CountrySubdiv_Name FROM DUAL
            ) A
            LEFT OUTER JOIN COUNTRYSUBDIV B
                ON A.Country_ID = B.Country_ID
                        AND CASE
                            WHEN A.Country_ID = 'CAN' AND UPPER(A.CountrySubdiv_Name) = 'NEWFOUNDLAND' THEN UPPER('Newfoundland and Labrador')
                            WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'CNMI' THEN 'MP'
                            WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'USVI' THEN 'VI'
                            WHEN A.Country_ID = 'USA' AND UPPER(A.CountrySubdiv_Name) = 'PUERTO RICO' THEN 'PR'
                            ELSE UPPER(A.CountrySubdiv_Name)
                        END
                        =
                        CASE
                            WHEN A.Country_ID = 'USA' THEN B.Code
                            ELSE UPPER(B.Name)
                        END
            WHERE A.Country_ID IS NOT NULL
            AND
            (
                NOT (INSTR(A.CountrySubdiv_Name, '-') <> 0)
                OR A.CountrySubdiv_Name IS NULL
            )
        )
        --
        SELECT Country_ID,
        NANP_ID,
        CountrySubdiv_Code
        FROM
        (
            SELECT Country_ID,
            NANP_ID,
            CountrySubdiv_Code
            FROM S_COUNTRYSUBDIV#NANP2
            --
            UNION ALL
            --
            SELECT B.ID AS Country_ID,
            A.NANP_ID,
            NULL AS CountrySubdiv_Code
            FROM S_COUNTRYSUBDIV#NANP2 A
            INNER JOIN COUNTRY B
                ON A.Country_ID = B.Parent$Country_ID
                        AND A.CountrySubdiv_Code = B.Alpha2
            WHERE (TRUNC(SYSDATE) >= B.DateStart OR B.DateStart IS NULL)
            AND (TRUNC(SYSDATE) <= B.DateEnd OR B.DateEnd IS NULL)
        )
        --
        MINUS
        --
        SELECT Country_ID,
        NANP_ID,
        CountrySubdiv_Code
        FROM COUNTRYSUBDIV#NANP;
        
        nRowsCOUNTRYSUBDIV#NANP := nRowsCOUNTRYSUBDIV#NANP + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('COUNTRYSUBDIV#NANP')
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
                'COUNTRYSUBDIV#NANP'
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
        
        
        IF nRowsNANP > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'NANP' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('NANP', vGoogleOutput);
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
            END;
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML(COALESCE(vGoogleOutput, vError)) || '</td>'
            || '</tr>';
            
        END IF;
        
        
        IF nRowsCOUNTRYSUBDIV#NANP > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'COUNTRYSUBDIV#NANP' || '</td>';
            
            BEGIN
                
                GOOGLE.Import_Table('COUNTRYSUBDIV#NANP', vGoogleOutput);
                
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
    
    REFRESH_NANP;
    
END;
/
*/