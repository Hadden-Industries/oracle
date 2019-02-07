SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_LANGUAGE
AS
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := 'LANGUAGE ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    bExists BOOLEAN := FALSE;
    nDeleted SIMPLE_INTEGER := 0;
    nInserted SIMPLE_INTEGER := 0;
    nUnmatchedLanguageScope SIMPLE_INTEGER := 0;
    nUnmatchedLanguageType SIMPLE_INTEGER := 0;
    nUpdated SIMPLE_INTEGER := 0;
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
            WHERE Table_Name IN
            (
                'LANGUAGESCOPE',
                'LANGUAGETYPE',
                'S_ISO639_3',
                'S_ISO639_3RETIREMENTS',
                'S_ISO639_6'
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
        INTO nUnmatchedLanguageScope
        FROM
        (
            SELECT Scope
            FROM S_ISO639_3
            WHERE Scope NOT IN
            (
                SELECT ID
                FROM LANGUAGESCOPE
            )
            GROUP BY Scope
        );
        
        IF nUnmatchedLanguageScope > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'LANGUAGESCOPE' || '</td>'
            || '<td>' || 'Missing' || '</td>'
            || '<td>' || TO_CHAR(nUnmatchedLanguageScope) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        ELSE
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('LANGUAGESCOPE')
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
        
        
        SELECT COUNT(*)
        INTO nUnmatchedLanguageType
        FROM
        (
            SELECT Language_Type
            FROM S_ISO639_3
            WHERE Language_Type NOT IN
            (
                SELECT ID
                FROM LANGUAGETYPE
            )
            GROUP BY Language_Type
        );
        
        IF nUnmatchedLanguageType > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'LANGUAGETYPE' || '</td>'
            || '<td>' || 'Missing' || '</td>'
            || '<td>' || TO_CHAR(nUnmatchedLanguageType) || '</td>'
            || '</tr>';
            
            RAISE HANDLED;
            
        ELSE
            
            FOR C IN
            (
                SELECT Table_Name
                FROM USER_TABLES
                WHERE Table_Name IN ('LANGUAGETYPE')
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
        
        
        FOR C IN
        (
            SELECT ID,
            Parent$Language_ID,
            LanguageScope_ID,
            LanguageType_ID,
            Name,
            Part1,
            Part2B,
            Part2T,
            DateStart,
            DateEnd,
            Comments
            FROM
            (
                SELECT ID,
                Parent$Language_ID,
                LanguageScope_ID,
                LanguageType_ID,
                Ref_Name AS Name,
                Part1,
                Part2B,
                Part2T,
                DateStart,
                DateEnd,
                Comments
                FROM
                (
                    SELECT A.ID,
                    NULL AS Parent$Language_ID,
                    A.Scope AS LanguageScope_ID,
                    A.Language_Type AS LanguageType_ID,
                    A.Ref_Name,
                    A.Part1,
                    A.Part2B,
                    A.Part2T,
                    CASE
                        WHEN B.Ret_Reason = 'C' THEN B.Effective
                        ELSE NULL
                    END AS DateStart,
                    NULL AS DateEnd,
                    A."COMMENT" AS Comments
                    FROM S_ISO639_3 A
                    LEFT OUTER JOIN S_ISO639_3RETIREMENTS B
                        ON A.ID = B.Change_To
                    WHERE A.ID IS NOT NULL
                    --Is not retired
                    AND NOT EXISTS
                    (
                        SELECT NULL
                        FROM S_ISO639_3RETIREMENTS C
                        WHERE C.ID = A.ID
                    )
                    --
                    UNION
                    --
                    SELECT ID,
                    NULL AS Parent$Language_ID,
                    NULL AS LanguageScope_ID,
                    NULL AS LanguageType_ID,
                    Ref_Name,
                    NULL AS Part1,
                    NULL AS Part2B,
                    NULL AS Part2T,
                    NULL AS DateStart,
                    Effective AS DateEnd,
                    Ret_Reason || ' ' || Change_To || ' ' || Ret_Remedy AS Comments
                    FROM S_ISO639_3RETIREMENTS
                ) A
                WHERE NOT EXISTS
                (
                    SELECT NULL
                    FROM S_ISO639_6 B
                    WHERE B.ID = A.ID
                )
                --
                UNION
                --
                SELECT X.ID,
                Z.ID AS Parent$Language_ID,
                Y.LanguageScope_ID,
                Y.LanguageType_ID,
                CASE
                    WHEN Y.Ref_Name IS NULL THEN X.Name --only pick the ISO639-6 name if none exists at ISO639-3
                    ELSE Y.Ref_Name
                END AS Name,
                Y.Part1,
                Y.Part2B,
                Y.Part2T,
                Y.DateStart,
                Y.DateEnd,
                CASE
                    WHEN X.Name <> Y.Ref_Name AND Y.Comments IS NULL THEN X.Name
                    ELSE Y.Comments
                END AS Comments
                FROM S_ISO639_6 X
                LEFT OUTER JOIN
                (
                    SELECT A.ID,
                    NULL AS Parent$Language_ID,
                    A.Scope AS LanguageScope_ID,
                    A.Language_Type AS LanguageType_ID,
                    A.Ref_Name,
                    A.Part1,
                    A.Part2B,
                    A.Part2T,
                    CASE
                        WHEN B.Ret_Reason = 'C' THEN B.Effective
                        ELSE NULL
                    END AS DateStart,
                    NULL AS DateEnd,
                    A."COMMENT" AS Comments
                    FROM S_ISO639_3 A
                    LEFT OUTER JOIN S_ISO639_3RETIREMENTS B
                        ON A.ID = B.Change_To
                    WHERE A.ID IS NOT NULL
                    --Is not retired
                    AND NOT EXISTS
                    (
                        SELECT NULL
                        FROM S_ISO639_3RETIREMENTS C
                        WHERE C.ID = A.ID
                    )
                    --
                    UNION ALL
                    --
                    SELECT ID,
                    NULL AS Parent$Language_ID,
                    NULL AS LanguageScope_ID,
                    NULL AS LanguageType_ID,
                    Ref_Name,
                    NULL AS Part1,
                    NULL AS Part2B,
                    NULL AS Part2T,
                    NULL AS DateStart,
                    Effective AS DateEnd,
                    Ret_Reason || ' ' || Change_To || ' ' || Ret_Remedy AS Comments
                    FROM S_ISO639_3RETIREMENTS
                ) Y
                    ON X.ID = Y.ID
                LEFT OUTER JOIN S_ISO639_6 Z
                    ON X.Parent$S_ISO639_6_ID = Z.ID
            )
            WHERE Name IS NOT NULL
        ) LOOP
            
            bExists := FALSE;
            
            FOR D IN
            (
                SELECT ID,
                Parent$Language_ID,
                LanguageScope_ID,
                LanguageType_ID,
                Name,
                UUID,
                DateEnd,
                DateStart,
                Part1,
                Part2B,
                Part2T,
                Comments
                FROM LANGUAGE
                WHERE LANGUAGE.ID = C.ID
            ) LOOP
                
                bExists := TRUE;
                
                
                IF COALESCE(C.Parent$Language_ID, CHR(0)) <> COALESCE(D.Parent$Language_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Parent$Language_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Parent$Language_ID = C.Parent$Language_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Parent$Language_ID || '=>' || C.Parent$Language_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.LanguageScope_ID, CHR(0)) <> COALESCE(D.LanguageScope_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.LanguageScope_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET LanguageScope_ID = C.LanguageScope_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.LanguageScope_ID || '=>' || C.LanguageScope_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.LanguageType_ID, CHR(0)) <> COALESCE(D.LanguageType_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.LanguageType_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET LanguageType_ID = C.LanguageType_ID
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.LanguageType_ID || '=>' || C.LanguageType_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.Name <> D.Name THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Name' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Name = C.Name
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Name || '=>' || C.Name || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) <> COALESCE(D.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.DateEnd' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET DateEnd = C.DateEnd
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TO_CHAR(D.DateEnd, 'YYYY-MM-DD') || '=>' || TO_CHAR(C.DateEnd, 'YYYY-MM-DD') || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateStart, TO_DATE('00010101', 'YYYYMMDD')) <> COALESCE(D.DateStart, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.DateStart' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET DateStart = C.DateStart
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TO_CHAR(D.DateStart, 'YYYY-MM-DD') || '=>' || TO_CHAR(C.DateStart, 'YYYY-MM-DD') || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Part1, CHR(0)) <> COALESCE(D.Part1, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Part1' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Part1 = C.Part1
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Part1 || '=>' || C.Part1 || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Part2B, CHR(0)) <> COALESCE(D.Part2B, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Part2B' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Part2B = C.Part2B
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Part2B || '=>' || C.Part2B || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Part2T, CHR(0)) <> COALESCE(D.Part2T, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Part2T' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Part2T = C.Part2T
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Part2T || '=>' || C.Part2T || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Comments, CHR(0)) <> COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || 'LANGUAGE.Comments' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    LANGUAGE
                    SET Comments = C.Comments
                    WHERE ID = C.ID;
                    
                    nUpdated := nUpdated + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Comments || '=>' || C.Comments || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
            END LOOP;
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || 'LANGUAGE' || '</td>'
                || '<td>'
                || 'ID: ' || C.ID || '<br />'
                || 'Parent$Language_ID: ' || C.Parent$Language_ID || '<br />'
                || 'LanguageScope_ID: ' || C.LanguageScope_ID || '<br />'
                || 'LanguageType_ID: ' || C.LanguageType_ID || '<br />'
                || 'Name: ' || TEXT_TO_HTML(C.Name) || '<br />'
                || 'DateEnd: ' || TO_CHAR(C.DateEnd, 'YYYY-MM-DD') || '<br />'
                || 'DateStart: ' || TO_CHAR(C.DateStart, 'YYYY-MM-DD') || '<br />'
                || 'Part1: ' || C.Part1 || '<br />'
                || 'Part2B: ' || C.Part2B || '<br />'
                || 'Part2T: ' || C.Part2T || '<br />'
                || 'Comments: ' || TEXT_TO_HTML(C.Comments)
                || '</td>';
                
                INSERT
                INTO LANGUAGE
                (
                    ID,
                    PARENT$LANGUAGE_ID,
                    LANGUAGESCOPE_ID,
                    LANGUAGETYPE_ID,
                    NAME,
                    UUID,
                    DATEEND,
                    DATESTART,
                    PART1,
                    PART2B,
                    PART2T,
                    COMMENTS
                )
                VALUES
                (
                    C.ID,
                    C.Parent$Language_ID,
                    C.LanguageScope_ID,
                    C.LanguageType_ID,
                    C.Name,
                    UNCANONICALISE_UUID(UUID_Ver4),
                    C.DateEnd,
                    C.DateStart,
                    C.Part1,
                    C.Part2B,
                    C.Part2T,
                    C.Comments
                );
                
                nInserted := nInserted + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT ID,
            Parent$Language_ID,
            LanguageScope_ID,
            LanguageType_ID,
            Name,
            UUID,
            DateEnd,
            DateStart,
            Part1,
            Part2B,
            Part2T,
            Comments
            FROM LANGUAGE
            WHERE ID NOT IN
            (
                SELECT ID
                FROM
                (
                    SELECT ID,
                    Parent$Language_ID,
                    LanguageScope_ID,
                    LanguageType_ID,
                    Ref_Name AS Name,
                    Part1,
                    Part2B,
                    Part2T,
                    DateStart,
                    DateEnd,
                    Comments
                    FROM
                    (
                        SELECT A.ID,
                        NULL AS Parent$Language_ID,
                        A.Scope AS LanguageScope_ID,
                        A.Language_Type AS LanguageType_ID,
                        A.Ref_Name,
                        A.Part1,
                        A.Part2B,
                        A.Part2T,
                        CASE
                            WHEN B.Ret_Reason = 'C' THEN B.Effective
                            ELSE NULL
                        END AS DateStart,
                        NULL AS DateEnd,
                        A."COMMENT" AS Comments
                        FROM S_ISO639_3 A
                        LEFT OUTER JOIN S_ISO639_3RETIREMENTS B
                            ON A.ID = B.Change_To
                        WHERE A.ID IS NOT NULL
                        --
                        UNION
                        --
                        SELECT ID,
                        NULL AS Parent$Language_ID,
                        NULL AS LanguageScope_ID,
                        NULL AS LanguageType_ID,
                        Ref_Name,
                        NULL AS Part1,
                        NULL AS Part2B,
                        NULL AS Part2T,
                        NULL AS DateStart,
                        Effective AS DateEnd,
                        Ret_Reason || ' ' || Change_To || ' ' || Ret_Remedy AS Comments
                        FROM S_ISO639_3RETIREMENTS
                    ) A
                    WHERE NOT EXISTS
                    (
                        SELECT NULL
                        FROM S_ISO639_6 B
                        WHERE B.ID = A.ID
                    )
                    --
                    UNION
                    --
                    SELECT X.ID,
                    Z.ID AS Parent$Language_ID,
                    Y.LanguageScope_ID,
                    Y.LanguageType_ID,
                    CASE
                        WHEN Y.Ref_Name IS NULL THEN X.Name --only pick the ISO639-6 name if none exists at ISO639-3
                        ELSE Y.Ref_Name
                    END AS Name,
                    Y.Part1,
                    Y.Part2B,
                    Y.Part2T,
                    Y.DateStart,
                    Y.DateEnd,
                    CASE
                        WHEN X.Name <> Y.Ref_Name AND Y.Comments IS NULL THEN X.Name
                        ELSE Y.Comments
                    END AS Comments
                    FROM S_ISO639_6 X
                    LEFT OUTER JOIN
                    (
                        SELECT A.ID,
                        NULL AS Parent$Language_ID,
                        A.Scope AS LanguageScope_ID,
                        A.Language_Type AS LanguageType_ID,
                        A.Ref_Name,
                        A.Part1,
                        A.Part2B,
                        A.Part2T,
                        CASE
                            WHEN B.Ret_Reason = 'C' THEN B.Effective
                            ELSE NULL
                        END AS DateStart,
                        NULL AS DateEnd,
                        A."COMMENT" AS Comments
                        FROM S_ISO639_3 A
                        LEFT OUTER JOIN S_ISO639_3RETIREMENTS B
                            ON A.ID = B.Change_To
                        --
                        UNION ALL
                        --
                        SELECT ID,
                        NULL AS Parent$Language_ID,
                        NULL AS LanguageScope_ID,
                        NULL AS LanguageType_ID,
                        Ref_Name,
                        NULL AS Part1,
                        NULL AS Part2B,
                        NULL AS Part2T,
                        NULL AS DateStart,
                        Effective AS DateEnd,
                        Ret_Reason || ' ' || Change_To || ' ' || Ret_Remedy AS Comments
                        FROM S_ISO639_3RETIREMENTS
                    ) Y
                        ON X.ID = Y.ID
                    LEFT OUTER JOIN S_ISO639_6 Z
                        ON X.Parent$S_ISO639_6_ID = Z.ID
                )
                WHERE ID IS NOT NULL
            )
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'DELETE' || '</td>'
            || '<td>' || 'LANGUAGE' || '</td>'
            || '<td>'
            || 'ID: ' || C.ID || '<br />'
            || 'Parent$Language_ID: ' || C.Parent$Language_ID || '<br />'
            || 'LanguageScope_ID: ' || C.LanguageScope_ID || '<br />'
            || 'LanguageType_ID: ' || C.LanguageType_ID || '<br />'
            || 'Name: ' || TEXT_TO_HTML(C.Name) || '<br />'
            || 'UUID: ' || C.UUID || '<br />'
            || 'DateEnd: ' || TO_CHAR(C.DateEnd, 'YYYY-MM-DD') || '<br />'
            || 'DateStart: ' || TO_CHAR(C.DateStart, 'YYYY-MM-DD') || '<br />'
            || 'Part1: ' || C.Part1 || '<br />'
            || 'Part2B: ' || C.Part2B || '<br />'
            || 'Part2T: ' || C.Part2T || '<br />'
            || 'Comments: ' || TEXT_TO_HTML(C.Comments)
            || '</td>';
            
            BEGIN
                
                DELETE
                FROM LANGUAGE
                WHERE LANGUAGE.ID = C.ID;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            EXCEPTION
            WHEN OTHERS THEN
                
                vError := SUBSTRB(SQLErrM, 1, 255);
                
                vMsg := vMsg || '<td>' || TEXT_TO_HTML(vError) || '</td>'
                || '</tr>';
                
            END;
            
        END LOOP;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('LANGUAGE')
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
            WHERE Table_Name IN ('LANGUAGE')
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
        
        
        IF nDeleted + nInserted + nUpdated > 0 THEN
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'REFRESH' || '</td>'
            || '<td>' || 'GOOGLE' || '</td>'
            || '<td>' || 'LANGUAGE' || '</td>';
            
            BEGIN
                
                vError := NULL;
                
                GOOGLE.Import_Table('LANGUAGE', vGoogleOutput);
                
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
    
    REFRESH_LANGUAGE;
    
END;
/
*/