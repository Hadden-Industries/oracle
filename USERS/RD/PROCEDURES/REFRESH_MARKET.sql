SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_MARKET(gDownload INTEGER DEFAULT 1)
AS
    
    vTable_Name USER_TABLES.Table_Name%TYPE := 'MARKET';
    
    --Email variables
    vSubject VARCHAR2(78 CHAR) := SUBSTRB(vTable_Name, 1, 58) || ' ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD"T"HH24:MI:SS');
    vMsg CLOB := EMPTY_CLOB();
    vSender VARCHAR2(4000 BYTE) := '';
    vRecipient VARCHAR2(4000 BYTE) := GET_EMAILS;
    vCC VARCHAR2(4000 BYTE) := '';
    vBCC VARCHAR2(4000 BYTE) := '';
    
    --Program variables
    dDateTimeModified DATE := SYSDATE;
    dInitialDateTimeModified DATE := SYSDATE;
    nCountUnmatched SIMPLE_INTEGER := 0;
    nRowsMarketAffected SIMPLE_INTEGER := 0;
    vGoogleOutput VARCHAR2(4000 BYTE) := '';
    vTimeStampFormat VARCHAR2(10 BYTE) := 'HH24:MI:SS';
    vURL VARCHAR2(4000 BYTE);
    xXML XMLTYPE;
    
    --Exception handling variables
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
        
        IF (gDownload = 1) THEN
            
            vURL := Get_Table_Refresh_Source_URL(vTable_Name);
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'WGET' || '</td>'
            || '<td>' || TEXT_TO_HTML(vURL) || '</td>'
            || '<td>' || '' || '</td>';
            
            BEGIN
                
                WGET(vURL);
                
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
        || '<td>' || 'VALIDATE' || '</td>'
        || '<td>' || 'XML' || '</td>'
        || '<td>' || '' || '</td>';
        
        xXML := XMLTYPE
        (
            BFileName('RD', 'ISO10383_MIC.xml'),
            NLS_CharSet_ID('AL32UTF8')
        );
        
        IF xXML.isSchemaValid('ISO_10383.xsd') = 1 THEN
            
            xXML.setSchemaValidated(1);
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        ELSE
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✗') || '</td>'
            || '</tr>';
            
            --RAISE HANDLED; --Do not raise an error as Oracle sometimes fails validation even if the data is correct
            
        END IF;
        
        
        FOR C IN
        (
            SELECT Table_Name
            FROM USER_TABLES
            WHERE Table_Name IN
            (
                'S_MARKETYAHOO'
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
                OWNNAME=>NULL,
                TABNAME=>C.Table_Name,
                METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE=>TRUE,
                ESTIMATE_PERCENT=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        FOR C IN
        (
            --Check if any markets don't get populated
            SELECT ID,
            Country_Name,
            TownName
            FROM ISO10383
            WHERE Country_Alpha2 != 'ZZ'
            AND ID IS NOT NULL
            AND ID NOT IN
            (
                SELECT ID
                FROM
                (
                    SELECT A.ID
                    FROM ISO10383 A
                    INNER JOIN COUNTRY B
                      ON A.Country_Alpha2 = B.Alpha2
                    INNER JOIN UNIQUECOUNTRY$TOWNNAME C
                      ON CASE
                                  WHEN A.ID = 'XGMX' THEN 'PRI' --http://www.gmegroup.us/index.php/contact-gme/105-globalclear-gme
                                  ELSE B.ID
                              END = C.Country_ID
                              AND C.Name = TRIM
                              (
                                  REGEXP_REPLACE
                                  (
                                      UPPER
                                      (
                                          CASE
                                              WHEN A.TownName = 'N/A' THEN NULL
                                              WHEN A.ID = 'BETP' THEN 'SARUGAKUCHO' --http://www.bloomberg.com/research/stocks/private/snapshot.asp?privcapId=284628616
                                              WHEN A.ID = 'BOVM' THEN 'BELO HORIZONTE' --Found on exchange's website
                                              WHEN A.ID IN ('PDQD', 'PDQX') THEN 'GLENVIEW' --Found on exchange's website
                                              WHEN A.ID = 'TERA' THEN 'SUMMIT'  --Found on exchange's website (25 DeForest Avenue, Suite 208, Summit, New Jersey 07901)
                                              WHEN A.ID = 'XADF' THEN 'WASHINGTON, D.C.'  --Found on exchange's website
                                              WHEN A.ID = 'XALB' THEN 'CALGARY' --http://en.wikipedia.org/wiki/Alberta_Stock_Exchange
                                              WHEN A.ID = 'XLAO' THEN 'VIENTIANE' --Found on exchange's website
                                              WHEN A.ID = 'XMNX' THEN 'PODGORICA' --Found on exchange's website
                                              WHEN A.ID = 'XSVA' THEN 'SAN SALVADOR' --Found on exchange's website
                                              WHEN A.ID = 'XTKA' THEN 'TOYOHASHI' --http://www.swiftbic.com/swift-code-XTKAJPJ1.html
                                              WHEN A.ID = 'IMCO' AND A.TownName = 'ATLANTA' THEN 'LONDON' --Confirmed in email, should be fixed in 2017-04 release
                                              WHEN B.Name = 'Germany' AND A.TownName = 'FRANKFURT' THEN 'FRANKFURT AM MAIN'
                                              WHEN B.Name = 'Greece' AND A.TownName = 'PIREAUS' THEN 'PIRAEUS' -- HEMO
                                              WHEN B.Name = 'Germany' AND A.TownName = 'UNTERSCHLEISSHEM' THEN 'UNTERSCHLEISSHEIM' --fixed in GeoNames 2017-10-07
                                              ELSE REPLACE(REGEXP_REPLACE(TRIM(A.TownName),'[[:blank:]]{2,}',' '), '-', ' ') --Remove duplicate spaces & Geonames alternate names ignore -
                                          END
                                      )
                                      , '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]'
                                      , ''
                                  )
                              )
                )
                WHERE ID IS NOT NULL
            )
        ) LOOP
            
            nCountUnmatched := nCountUnmatched + 1;
            
            vMsg := vMsg || CHR(10)
            || '<tr>'
            || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
            || '<td>' || 'CHECK' || '</td>'
            || '<td>' || 'Unmatched town for ' || C.ID || '</td>'
            || '<td>' || TEXT_TO_HTML(C.Country_Name) || '</td>'
            || '<td>' || TEXT_TO_HTML(C.TownName) || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
        IF nCountUnmatched > 0 THEN
            
            RAISE HANDLED;
            
        END IF;
        
        
        --Note that AIMX was de-activated 2007-12-13 as per http://www.londonstockexchange.com/products-and-services/reference-data/sedol-master-file/mic.htm
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || 'Delete' || '</td>';
        
        MERGE
        INTO MARKET X
        USING
        (
            SELECT ID,
            CASE
                WHEN DateGenerated < TO_DATE('2012-02-01', 'YYYY-MM-DD') THEN DateGenerated
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-02' THEN TO_DATE('2012-02-20', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-03' THEN TO_DATE('2012-03-19', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-04' THEN TO_DATE('2012-04-16', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-05' THEN TO_DATE('2012-05-21', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-06' THEN TO_DATE('2012-06-18', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-07' THEN TO_DATE('2012-07-16', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-08' THEN TO_DATE('2012-08-27', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-09' THEN TO_DATE('2012-09-24', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-10' THEN TO_DATE('2012-10-22', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-11' THEN TO_DATE('2012-11-26', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2012-12' THEN TO_DATE('2012-12-24', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2013-01' THEN TO_DATE('2013-01-21', 'YYYY-MM-DD')
                WHEN TO_CHAR(DateGenerated, 'YYYY-MM') = '2013-03' THEN TO_DATE('2013-03-18', 'YYYY-MM-DD')
                WHEN TO_CHAR
                (
                    TRUNC(DateGenerated, 'MM'),
                    'DY'
                ) = 'MON' THEN TRUNC(DateGenerated, 'MM') + (3*7) --Fourth Monday of the month
                ELSE NEXT_DAY
                (
                    TRUNC(DateGenerated, 'MM'),
                    'MONDAY'
                ) + (3*7) --Fourth Monday of the month
            END AS DateEnd
            FROM
            (
                SELECT ID,
                (
                    SELECT TRUNC
                    (
                        CAST
                        (
                            MAX(DateTimeGenerated) AS DATE
                        )
                    )
                    FROM ISO10383
                ) AS DateGenerated
                FROM MARKET
                WHERE
                (
                    DateEnd IS NULL
                    OR TRUNC(SYSDATE_UTC) < DateEnd
                )
                AND ID NOT IN
                (
                    SELECT ID
                    FROM ISO10383
                    WHERE ID IS NOT NULL
                )
            )
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.DateEnd = Y.DateEnd;
        
        nRowsMarketAffected := nRowsMarketAffected + SQL%ROWCOUNT;
        
        vMsg := vMsg || '<td>' || TO_CHAR(SQL%ROWCOUNT) || '</td>'
        || '</tr>';
        
        
        vMsg := vMsg || CHR(10)
        || '<tr>'
        || '<td>' || TO_CHAR(SYSDATE, vTimeStampFormat) || '</td>'
        || '<td>' || 'MERGE' || '</td>'
        || '<td>' || vTable_Name || '</td>'
        || '<td>' || 'Upsert' || '</td>';
        
        MERGE
        INTO MARKET X
        USING
        (
            SELECT ID,
            Parent$Market_ID,
            GeoNames_ID,
            Name,
            Acronym,
            DateModified,
            URL,
            YahooFinanceSuffix,
            DateStart,
            Comments
            FROM
            (
                SELECT ID,
                CASE
                    WHEN ID = Parent$Market_ID THEN NULL
                    ELSE Parent$Market_ID
                END AS Parent$Market_ID,
                GeoNames_ID,
                Name,
                Acronym,
                DateModified,
                URL,
                YahooFinanceSuffix,
                CASE
                    WHEN DateStart < TO_DATE('2012-02-01', 'YYYY-MM-DD') THEN DateStart
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-02' THEN TO_DATE('2012-02-20', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-03' THEN TO_DATE('2012-03-19', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-04' THEN TO_DATE('2012-04-16', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-05' THEN TO_DATE('2012-05-21', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-06' THEN TO_DATE('2012-06-18', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-07' THEN TO_DATE('2012-07-16', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-08' THEN TO_DATE('2012-08-27', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-09' THEN TO_DATE('2012-09-24', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-10' THEN TO_DATE('2012-10-22', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-11' THEN TO_DATE('2012-11-26', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2012-12' THEN TO_DATE('2012-12-24', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2013-01' THEN TO_DATE('2013-01-21', 'YYYY-MM-DD')
                    WHEN TO_CHAR(DateStart, 'YYYY-MM') = '2013-03' THEN TO_DATE('2013-03-18', 'YYYY-MM-DD')
                    WHEN TO_CHAR(TRUNC(DateStart, 'MM'), 'DY') = 'MON' THEN TRUNC(DateStart, 'MM') + (3*7) --Fourth Monday of the month
                    ELSE NEXT_DAY(TRUNC(DateStart, 'MM'), 'MONDAY') + (3*7) --Fourth Monday of the month
                END AS DateStart,
                Comments
                FROM
                (
                    SELECT A.ID,
                    COALESCE(A.Parent$ISO10383_ID, A.ID) AS Parent$Market_ID,
                    C.GeoNames_ID,
                    A.Name,
                    A.Acronym,
                    CASE
                        WHEN A.DateModified = 'BEFORE JUNE 2005' THEN TO_DATE('2005-05-31', 'YYYY-MM-DD')
                        ELSE TO_DATE(A.DateModified, 'Month YYYY')
                    END AS DateModified,
                    A.URL,
                    CASE
                        WHEN SUBSTR(E.Suffix, 1, 1) = '.' AND LENGTH(E.Suffix) <= 4 THEN E.Suffix
                        ELSE NULL
                    END AS YahooFinanceSuffix,
                    CASE
                        WHEN A.DateStart = 'BEFORE JUNE 2005' THEN TO_DATE('2005-05-31', 'YYYY-MM-DD')
                        ELSE TO_DATE(A.DateStart, 'Month YYYY')
                    END AS DateStart,
                    A.Comments
                    FROM ISO10383 A
                    INNER JOIN COUNTRY B
                      ON A.Country_Alpha2 = B.Alpha2
                    INNER JOIN UNIQUECOUNTRY$TOWNNAME C
                      ON CASE
                                  WHEN A.ID = 'XGMX' THEN 'PRI' --http://www.gmegroup.us/index.php/contact-gme/105-globalclear-gme
                                  ELSE B.ID
                              END = C.Country_ID
                              AND C.Name = TRIM
                              (
                                  REGEXP_REPLACE
                                  (
                                      UPPER
                                      (
                                          CASE
                                              WHEN A.TownName = 'N/A' THEN NULL
                                              WHEN A.ID = 'BETP' THEN 'SARUGAKUCHO' --http://www.bloomberg.com/research/stocks/private/snapshot.asp?privcapId=284628616
                                              WHEN A.ID = 'BOVM' THEN 'BELO HORIZONTE' --Found on exchange's website
                                              WHEN A.ID IN ('PDQD', 'PDQX') THEN 'GLENVIEW' --Found on exchange's website
                                              WHEN A.ID = 'TERA' THEN 'SUMMIT'  --Found on exchange's website (25 DeForest Avenue, Suite 208, Summit, New Jersey 07901)
                                              WHEN A.ID = 'XADF' THEN 'WASHINGTON, D.C.'  --Found on exchange's website
                                              WHEN A.ID = 'XALB' THEN 'CALGARY' --http://en.wikipedia.org/wiki/Alberta_Stock_Exchange
                                              WHEN A.ID = 'XLAO' THEN 'VIENTIANE' --Found on exchange's website
                                              WHEN A.ID = 'XMNX' THEN 'PODGORICA' --Found on exchange's website
                                              WHEN A.ID = 'XSVA' THEN 'SAN SALVADOR' --Found on exchange's website
                                              WHEN A.ID = 'XTKA' THEN 'TOYOHASHI' --http://www.swiftbic.com/swift-code-XTKAJPJ1.html
                                              WHEN A.ID = 'IMCO' AND A.TownName = 'ATLANTA' THEN 'LONDON' --Confirmed in email, should be fixed in 2017-04 release
                                              WHEN B.Name = 'Germany' AND A.TownName = 'FRANKFURT' THEN 'FRANKFURT AM MAIN'
                                              WHEN B.Name = 'Greece' AND A.TownName = 'PIREAUS' THEN 'PIRAEUS' -- HEMO
                                              WHEN B.Name = 'Germany' AND A.TownName = 'UNTERSCHLEISSHEM' THEN 'UNTERSCHLEISSHEIM' --fixed in GeoNames 2017-10-07
                                              ELSE REPLACE(REGEXP_REPLACE(TRIM(A.TownName),'[[:blank:]]{2,}',' '), '-', ' ') --Remove duplicate spaces & Geonames alternate names ignore -
                                          END
                                      ),
                                      '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                                      ''
                                  )
                              )
                    LEFT OUTER JOIN S_MARKETYAHOO E
                        ON CASE A.ID
                                    WHEN 'BATS' THEN 'BATS Exchange'
                                    WHEN 'XCBT' THEN 'Chicago Board of Trade'
                                    WHEN 'XCME' THEN 'Chicago Mercantile Exchange'
                                    WHEN 'XNAS' THEN 'NASDAQ Stock Exchange'
                                    WHEN 'IFUS' THEN 'New York Board of Trade'
                                    WHEN 'XNYM' THEN 'New York Mercantile Exchange'
                                    WHEN 'XNYS' THEN 'New York Stock Exchange'
                                    WHEN 'XOTC' THEN 'OTC Bulletin Board Market'
                                    WHEN 'OTCM' THEN 'Pink Sheets'
                                    WHEN 'XMEV' THEN 'Buenos Aires Stock Exchange'
                                    WHEN 'XVIE' THEN 'Vienna Stock Exchange'
                                    WHEN 'XASX' THEN 'Australian Stock Exchange'
                                    WHEN 'BVMF' THEN 'BOVESPA - Sao Paolo Stock Exchange'
                                    WHEN 'XTSE' THEN 'Toronto Stock Exchange'
                                    WHEN 'XTSX' THEN 'TSX Venture Exchange'
                                    WHEN 'XSGO' THEN 'Santiago Stock Exchange'
                                    WHEN 'XSHG' THEN 'Shanghai Stock Exchange'
                                    WHEN 'XSHE' THEN 'Shenzhen Stock Exchange'
                                    WHEN 'XCSE' THEN 'Copenhagen Stock Exchange'
                                    WHEN 'XPAR' THEN 'Paris Stock Exchange'
                                    WHEN 'XBER' THEN 'Berlin Stock Exchange'
                                    WHEN 'XBRE' THEN 'Bremen Stock Exchange'
                                    WHEN 'XDUS' THEN 'Dusseldorf Stock Exchange'
                                    WHEN 'XFRA' THEN 'Frankfurt Stock Exchange'
                                    WHEN 'XHAM' THEN 'Hamburg Stock Exchange'
                                    WHEN 'XMUN' THEN 'Munich Stock Exchange'
                                    WHEN 'XSTU' THEN 'Stuttgart Stock Exchange'
                                    WHEN 'XETR' THEN 'XETRA Stock Exchange'
                                    WHEN 'XHKG' THEN 'Hong Kong Stock Exchange'
                                    WHEN 'XBOM' THEN 'Bombay Stock Exchange'
                                    WHEN 'XNSE' THEN 'National Stock Exchange of India'
                                    WHEN 'XJKT' THEN 'Jakarta Stock Exchange'
                                    WHEN 'XTAE' THEN 'Tel Aviv Stock Exchange'
                                    WHEN 'XMIL' THEN 'Milan Stock Exchange'
                                    WHEN 'XMEX' THEN 'Mexico Stock Exchange'
                                    WHEN 'XAMS' THEN 'Amsterdam Stock Exchange'
                                    WHEN 'XNZE' THEN 'New Zealand Stock Exchange'
                                    WHEN 'XOSL' THEN 'Oslo Stock Exchange'
                                    WHEN 'XSES' THEN 'Singapore Stock Exchange'
                                    WHEN 'XKRX' THEN 'Korea Stock Exchange'
                                    WHEN 'XKOS' THEN 'KOSDAQ'
                                    WHEN 'XBAR' THEN 'Barcelona Stock Exchange'
                                    WHEN 'XBIL' THEN 'Bilbao Stock Exchange'
                                    WHEN 'XMAD' THEN 'Madrid Stock Exchange'
                                    WHEN 'XSTO' THEN 'Stockholm Stock Exchange'
                                    WHEN 'XVTX' THEN 'Swiss Exchange'
                                    WHEN 'XTAI' THEN 'Taiwan Stock Exchange'
                                    WHEN 'ROCO' THEN 'Taiwan OTC Exchange'
                                    WHEN 'XLON' THEN 'London Stock Exchange'
                                    ELSE A.ID
                                END = E.Market_Name
                    WHERE A.ID IS NOT NULL
                    --to pick up 'XXXX'
                    UNION ALL
                    --
                    SELECT A.ID,
                    CASE
                        WHEN A.ID = A.Parent$ISO10383_ID THEN NULL
                        ELSE A.Parent$ISO10383_ID
                    END AS Parent$Market_ID,
                    NULL AS GeoNames_ID,
                    A.Name,
                    A.Acronym,
                    TO_DATE(A.DateModified, 'Month YYYY') AS DateModified,
                    A.URL,
                    NULL AS YahooFinanceSuffix,
                    TO_DATE(A.DateStart, 'Month YYYY') AS DateStart,
                    TRIM(A.Comments) AS Comments
                    FROM ISO10383 A
                    WHERE A.Country_Alpha2 = 'ZZ'
                )
                --
                MINUS
                --
                SELECT ID,
                Parent$Market_ID,
                GeoNames_ID,
                Name,
                Acronym,
                DateModified,
                URL,
                YahooFinanceSuffix,
                DateStart,
                Comments
                FROM MARKET
                WHERE DateEnd IS NULL
            )
            ORDER BY CASE
                --Parents are inserted first to prevent FK errors
                WHEN Parent$Market_ID IS NULL THEN 0
                ELSE 1
            END
        ) Y
            ON (X.ID = Y.ID)
        WHEN MATCHED THEN UPDATE SET X.Parent$Market_ID = Y.Parent$Market_ID,
        X.GeoNames_ID = Y.GeoNames_ID,
        X.Name = Y.Name,
        X.Acronym = Y.Acronym,
        X.DateModified = Y.DateModified,
        X.URL = Y.URL,
        X.YahooFinanceSuffix = Y.YahooFinanceSuffix,
        X.DateStart = Y.DateStart,
        X.Comments = Y.Comments
        WHEN NOT MATCHED THEN INSERT
        (
            ID,
            PARENT$MARKET_ID,
            GEONAMES_ID,
            NAME,
            UUID,
            ACRONYM,
            DATEMODIFIED,
            URL,
            YAHOOFINANCESUFFIX,
            DATESTART,
            COMMENTS
        )
        VALUES
        (
            Y.ID,
            Y.Parent$Market_ID,
            Y.GeoNames_ID,
            Y.Name,
            UNCANONICALISE_UUID(UUID_Ver4),
            Y.Acronym,
            Y.DateModified,
            Y.URL,
            Y.YahooFinanceSuffix,
            Y.DateStart,
            Y.Comments
        );
        
        nRowsMarketAffected := nRowsMarketAffected + SQL%ROWCOUNT;
        
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
            WHERE Table_Name IN
            (
                vTable_Name
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
                OWNNAME=>NULL,
                TABNAME=>C.Table_Name,
                METHOD_OPT=>'FOR ALL COLUMNS SIZE SKEWONLY',
                CASCADE=>TRUE,
                ESTIMATE_PERCENT=>100
            );
            
            vMsg := vMsg || '<td>' || TEXT_TO_HTML('✓') || '</td>'
            || '</tr>';
            
        END LOOP;
        
        
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
        
        ROLLBACK;
        
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
    
    REFRESH_MARKET(0);
    
END;
/
*/