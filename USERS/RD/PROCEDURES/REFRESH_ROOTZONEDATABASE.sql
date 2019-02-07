SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_ROOTZONEDATABASE
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'ROOTZONEDATABASE';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    cTmp CLOB;
    nDeletes SIMPLE_INTEGER := 0;
    bExists BOOLEAN := FALSE;
    nRowsROOTZONEDATABASE SIMPLE_INTEGER := 0;
    nTLDTYPEMissing SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vURL VARCHAR2(4000 BYTE);
    xXML XMLTYPE;
    
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
            
            vURL := Get_Table_Refresh_Source_URL(vTable_Name);
            
            SAVE_DATA_FROM_URL(vURL, vTable_Name);
            
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
                    vTable_Name,
                    'S_ROOTZONEDATABASE',
                    'TLDTYPE'
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
        || '<td>' || 'COMMIT' || '</td>'
        || '<td>' || USER || '</td>'
        || '<td>' || '' || '</td>';
        
        COMMIT;
        
        vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Offset,
            Position_End - Offset + LENGTH('</table>') AS Amount,
            Data
            FROM
            (
                SELECT DBMS_LOB.INSTR(Data, '<table', 1, 1) AS Offset,
                DBMS_LOB.INSTR(Data, '</table>', 1, 1) AS Position_End,
                Data
                FROM LATEST$INBOUND X
                WHERE X.TableLookup_Name = vTable_Name
            )
        ) LOOP
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CREATE' || '</td>'
            || '<td>' || 'Table CLOB' || '</td>'
            || '<td>' || '' || '</td>';
            
            DBMS_LOB.CreateTemporary(cTmp, TRUE);
            
            DBMS_LOB.Copy(cTmp, C.Data, C.Amount, 1, C.Offset);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || 'S_ROOTZONEDATABASE' || '</td>'
        || '<td>' || '' || '</td>';
        
        MERGE /*+ NO_PARALLEL */
        INTO S_ROOTZONEDATABASE X
        USING
        (
            SELECT UPPER(ID) AS ID,
            TLDType,
            OrganisationSponsor
            FROM
            (
                SELECT A.ID AS ID_0,
                B.ID ID_1,
                B.td
                FROM
                (
                    /*SELECT XMLTRANSFORM
                    (
                        XMLPARSE(DOCUMENT Data),
                        (
                            SELECT XML
                            FROM XSLT
                            WHERE Name = 'REMOVE_COMMENTS'
                        )
                    ) AS xXML
                    FROM INBOUND X
                    WHERE X.TableLookup_Name = 'ROOTZONEDATABASE'
                    AND X.DateTimeX =
                    (
                        SELECT MAX(Y.DateTimeX)
                        FROM INBOUND Y
                        WHERE X.TableLookup_Name = Y.TableLookup_Name
                    )*/
                    SELECT XMLTRANSFORM
                    (
                        XMLPARSE(DOCUMENT cTmp),
                        (
                            SELECT XML
                            FROM XSLT
                            WHERE Name = 'REMOVE_COMMENTS'
                        )
                    ) AS xXML
                    FROM DUAL
                ) XML
                INNER JOIN XMLTABLE
                (
                    '/table/tbody/tr' PASSING XML.xXML
                    COLUMNS ID FOR ORDINALITY,
                    tbody_tr_td XMLTYPE PATH 'td'
                ) A
                    ON 1 = 1
                INNER JOIN XMLTABLE
                (
                    '/td' PASSING A.tbody_tr_td
                    COLUMNS ID FOR ORDINALITY,
                    td VARCHAR2(4000 BYTE) PATH '.'
                ) B
                    ON 1 = 1
            )
            PIVOT
            (
                MIN(TD)
                FOR ID_1 IN
                (
                    1 AS ID,
                    2 AS TLDType,
                    3 AS OrganisationSponsor
                )
            )
            --
            MINUS
            --
            SELECT ID,
            TLDType,
            OrganisationSponsor
            FROM S_ROOTZONEDATABASE
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.TLDType = Y.TLDType,
        X.OrganisationSponsor = Y.OrganisationSponsor
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            TLDTYPE,
            ORGANISATIONSPONSOR
        )
        VALUES
        (
            Y.ID,
            Y.TLDType,
            Y.OrganisationSponsor
        );
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('S_ROOTZONEDATABASE')
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
            SELECT A.TLDType,
            COUNT(*) AS Cnt
            FROM S_ROOTZONEDATABASE A
            WHERE UPPER
            (
                REGEXP_REPLACE(A.TLDType, '[^[:alnum:]]', '')
            )
            IS NOT NULL
            AND UPPER
            (
                REGEXP_REPLACE(A.TLDType, '[^[:alnum:]]', '')
            ) NOT IN
            (
                SELECT UPPER
                (
                    REGEXP_REPLACE(Name, '[^[:alnum:]]', '')
                )
                FROM TLDTYPE
                WHERE UPPER
                (
                    REGEXP_REPLACE(Name, '[^[:alnum:]]', '')
                )
                IS NOT NULL
            )
            GROUP BY A.TLDType
        ) LOOP
            
            nTLDTYPEMissing := nTLDTYPEMissing + 1;
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'S_ROOTZONEDATABASE (Missing TLDTYPE)' || '</td>'
            || '<td>' || TEXT_TO_HTML(C.TLDType) || '</td>'
            || '<td>' || TO_CHAR(C.Cnt) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nTLDTYPEMissing > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN ('TLDTYPE')
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
            SELECT ID,
            Country_ID,
            TLDType_ID,
            OrganisationSponsor,
            Purpose
            FROM
            (
                SELECT REPLACE(A.ID, '.') AS ID,
                A.Country_ID,
                B.ID AS TLDType_ID,
                A.OrganisationSponsor,
                A.Purpose
                FROM 
                (
                    SELECT UPPER
                    (
                        TRIM(A.ID)
                    ) AS ID,
                    B.Country_ID,
                    TRIM(A.TLDType) AS TLDType,
                    CASE
                        WHEN B.Country_ID IS NOT NULL THEN NULL
                        ELSE A.Purpose
                    END AS Purpose,
                    A.OrganisationSponsor
                    FROM S_ROOTZONEDATABASE A
                    LEFT OUTER JOIN UNIQUE$COUNTRYNAME B
                        ON TRIM
                                (
                                    REGEXP_REPLACE
                                    (
                                        REGEXP_REPLACE
                                        (
                                            UPPER
                                            (
                                                REPLACE(A.Purpose, '(being phased out)', '')
                                            ),
                                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                            ''
                                        ),
                                        '[[:blank:]]{2,}',
                                        ' '
                                    )
                                ) = B.Name
                    WHERE TRIM(A.TLDType) = 'country-code'
                    --
                    UNION ALL
                    --
                    SELECT UPPER
                    (
                        TRIM(A.ID)
                    ) AS ID,
                    NULL AS Country_ID,
                    TRIM(A.TLDType) AS TLDType,
                    TRIM(A.Purpose) AS Purpose,
                    TRIM(A.OrganisationSponsor) AS OrganisationSponsor
                    FROM S_ROOTZONEDATABASE A
                    WHERE TRIM(A.TLDType) != 'country-code'
                    --
                    UNION ALL
                    --
                    SELECT '.YU' AS ID,
                    ID AS Country_ID,
                    'Expired' AS TLDType,
                    NULL AS Purpose,
                    'YUNET Association' AS OrganisationSponsor
                    FROM COUNTRY
                    WHERE Name = 'Yugoslavia'
                ) A
                INNER JOIN TLDTYPE B
                    ON UPPER
                            (
                                REGEXP_REPLACE(A.TLDType, '[^[:alnum:]]', '')
                            ) = UPPER
                            (
                                REGEXP_REPLACE(B.Name, '[^[:alnum:]]', '')
                            )
            )
            --
            MINUS
            --
            SELECT ID,
            Country_ID,
            TLDType_ID,
            OrganisationSponsor,
            Purpose
            FROM ROOTZONEDATABASE
            ORDER BY 1
        ) LOOP
            
            
            bExists := FALSE;
            
            
            FOR D IN
            (
                SELECT ID,
                Country_ID,
                TLDType_ID,
                OrganisationSponsor,
                Purpose
                FROM ROOTZONEDATABASE
                WHERE ID = C.ID
            ) LOOP
                
                
                bExists := TRUE;
                
                
                IF COALESCE(C.Country_ID, CHR(0)) != COALESCE(D.Country_ID, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Country_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET Country_ID = C.Country_ID
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.Country_ID || '=>' || C.Country_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF C.TLDType_ID != D.TLDType_ID THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.TLDType_ID' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET TLDType_ID = C.TLDType_ID
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.TLDType_ID || '=>' || C.TLDType_ID || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                /*IF COALESCE(C.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateEnd, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.DateEnd' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET DateEnd = C.DateEnd
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateEnd || '=>' || C.DateEnd || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.DateStart, TO_DATE('00010101', 'YYYYMMDD')) != COALESCE(D.DateStart, TO_DATE('00010101', 'YYYYMMDD')) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.DateStart' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET DateStart = C.DateStart
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || D.DateStart || '=>' || C.DateStart || ')' || '</td>'
                    || '</tr>';
                    
                END IF;*/
                
                
                IF COALESCE(C.OrganisationSponsor, CHR(0)) != COALESCE(D.OrganisationSponsor, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.OrganisationSponsor' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET OrganisationSponsor = C.OrganisationSponsor
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.OrganisationSponsor) || '=>' || TEXT_TO_HTML(C.OrganisationSponsor) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                IF COALESCE(C.Purpose, CHR(0)) != COALESCE(D.Purpose, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Purpose' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET Purpose = C.Purpose
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Purpose) || '=>' || TEXT_TO_HTML(C.Purpose) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;
                
                
                /*IF COALESCE(C.Comments, CHR(0)) != COALESCE(D.Comments, CHR(0)) THEN
                    
                    vMsg := vMsg || CHR(10)
                    ||  '<tr>'
                    || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                    || '<td>' || 'UPDATE' || '</td>'
                    || '<td>' || vTable_Name || '.Comments' || '</td>'
                    || '<td>' || C.ID || '</td>';
                    
                    UPDATE
                    ROOTZONEDATABASE
                    SET Comments = C.Comments
                    WHERE ID = C.ID;
                    
                    nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                    
                    vMsg := vMsg || '<td>' || ' (' || TEXT_TO_HTML(D.Comments) || '=>' || TEXT_TO_HTML(C.Comments) || ')' || '</td>'
                    || '</tr>';
                    
                END IF;*/
                
                
            END LOOP;
            
            
            IF NOT bExists THEN
                
                vMsg := vMsg || CHR(10)
                || '<tr>'
                || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
                || '<td>' || 'INSERT' || '</td>'
                || '<td>' || vTable_Name || '</td>'
                || '<td>' || C.ID || ','
                || C.Country_ID || ','
                || C.TLDType_ID || ','
                || TEXT_TO_HTML(C.OrganisationSponsor) || ','
                || TEXT_TO_HTML(C.Purpose) || '</td>';
                
                INSERT
                INTO ROOTZONEDATABASE
                (
                    ID,
                    UUID,
                    COUNTRY_ID,
                    TLDTYPE_ID,
                    ORGANISATIONSPONSOR,
                    PURPOSE
                )
                VALUES
                (
                    C.ID,
                    UNCANONICALISE_UUID(UUID_Ver4),
                    C.Country_ID,
                    C.TLDType_ID,
                    C.OrganisationSponsor,
                    C.Purpose
                );
                
                nRowsROOTZONEDATABASE := nRowsROOTZONEDATABASE + SQL%ROWCOUNT;
                
                vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
                || '</tr>';
                
            END IF;
            
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
                ownname => NULL,
                tabname => C.Table_Name,
                method_opt => 'FOR ALL COLUMNS SIZE SKEWONLY',
                cascade => TRUE,
                estimate_percent => 100
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
        
        
        IF nRowsROOTZONEDATABASE > 0 THEN
            
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
    
    REFRESH_ROOTZONEDATABASE;
    
END;
/

--header rows
SELECT B.*
FROM
(
    SELECT XMLTRANSFORM
    (
        XMLPARSE(DOCUMENT X.Data),
        (
            SELECT XML
            FROM XSLT
            WHERE Name = 'REMOVE_COMMENTS'
        )
    )
    AS xXML
    FROM INBOUND X
    WHERE X.TableLookup_Name = 'ROOTZONEDATABASE'
    AND X.DateTimeX =
    (
        SELECT MAX(Y.DateTimeX)
        FROM INBOUND Y
        WHERE X.TableLookup_Name = Y.TableLookup_Name
    )
) XML
INNER JOIN XMLTABLE
(
    '/table' PASSING XML.xXML
    COLUMNS thead_tr_th XMLTYPE PATH 'thead/tr/th'
) A
    ON 1 = 1
INNER JOIN XMLTABLE
(
    '/th' PASSING A.thead_tr_th
    COLUMNS ID FOR ORDINALITY,
    th VARCHAR2(4000 BYTE) PATH '.'
) B
    ON 1 = 1;
*/