SET DEFINE OFF;

CREATE OR REPLACE
FUNCTION TABLE_TO_HTML(gTableName IN VARCHAR2)
RETURN CLOB
AS
    
    cHTMLFragment CLOB := EMPTY_CLOB();
    vDDLURL DBMS#TABLELOOKUP.URL%TYPE := '';
    vTableName VARCHAR2(30 BYTE) := ORACLE_NAME(gTableName);
    
BEGIN
    
    FOR C IN
    (
        SELECT B.Name AS MasterDataType_Name,
        REPLACE(C.Name, '/', '/&#x200B;') AS TimeFrequency_Name,
        TO_CHAR(A.DateTimeUpdated, 'YYYY-MM-DD') AS DateUpdated,
        TO_CHAR(A.DateTimeUpdated, '"T"HH24:MI:SS') AS TimeUpdated,
        REPLACE
        (
            REPLACE(A.Description, '''', '&#39;'),
            CHR(10),
            '<br />'
        ) AS Description,
        A.NameFull,
        A.NameMedialCapital,
        A.URL
        FROM TABLELOOKUP A
        INNER JOIN MASTERDATATYPE B
            ON A.MasterDataType_ID = B.ID
        INNER JOIN TIMEFREQUENCY C
            ON A.TimeFrequency_ID = C.ID
        WHERE A.Name = vTableName
    ) LOOP
    
    cHTMLFragment := '        <div class="container grid-50 tablet-grid-100 mobile-grid-100">
            <div id="' || LOWER(vTableName) || '" class="card">
                <div class="flippable front">
                    <table>
                        <tbody>
                            <tr>
                                <td>
                                    <h2>' || C.NameMedialCapital || '</h2>
                                    <label title="' || C.MasterDataType_Name || '">
                                        <img src="images/starfull.svg" alt="star1" height="12" width="12">
                                        <img src="images/' || CASE WHEN C.MasterDataType_Name IN ('Market master data', 'Enterprise master data', 'Master data') THEN 'starfull.svg' ELSE 'starempty.svg' END || '" alt="star2" height="12" width="12">
                                        <img src="images/' || CASE WHEN C.MasterDataType_Name IN ('Market master data', 'Enterprise master data') THEN 'starfull.svg' ELSE 'starempty.svg' END || '" alt="star3" height="12" width="12">
                                        <img src="images/' || CASE WHEN C.MasterDataType_Name = 'Market master data' THEN 'starfull.svg' ELSE 'starempty.svg' END || '" alt="star4" height="12" width="12">
                                    </label>
                                    <div class="details">
                                        <p>' || C.Description || '</p>';
    
    FOR E IN
    (
        SELECT SourceName,
        SourceURL,
        ROW_NUMBER() OVER (PARTITION BY TableLookup_Name ORDER BY Rank, SourceName, SourceURL) AS RN,
        COUNT(*) OVER (PARTITION BY TableLookup_Name) AS Cnt
        FROM
        (
            SELECT TableLookup_Name,
            SourceName,
            SourceURL,
            Rank
            FROM TABLESOURCE AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP)
            WHERE TableLookup_Name = vTableName
            --
            UNION
            --
            SELECT A.Name AS TableLookup_Name,
            C.SourceName,
            C.SourceURL,
            C.Rank
            FROM TABLELOOKUP A
            INNER JOIN TABLELOOKUP B
                ON A.ProcedureRefresh = B.ProcedureRefresh
            INNER JOIN TABLESOURCE AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) C
                ON B.Name = C.TableLookup_Name
            WHERE A.Name = vTableName
            AND A.Name != B.Name
        )
    ) LOOP
        
        IF E.RN = 1 THEN
            
            cHTMLFragment := cHTMLFragment || '
                                        <label>Source'
            || CASE
                WHEN E.Cnt > 1 THEN 's'
                ELSE NULL
            END || '</label>
                                        <ul class="sources">';
            
        END IF;
        
        cHTMLFragment := cHTMLFragment || '
                                            <li>
                                                <a class="external" href="' || E.SourceURL || '" title="External link: Opens in a new tab">' || E.SourceName || '</a>
                                            </li>';
        
        IF E.RN = E.Cnt THEN
            
            cHTMLFragment := cHTMLFragment || '
                                        </ul>';
            
        END IF;
        
    END LOOP;
    
    cHTMLFragment := cHTMLFragment || '
                                    </div>
                                </td>
                                <td>
                                    <label>Rows</label>
                                    <p>
                                        <b>';
    
    FOR D IN
    (
        SELECT CountX
        FROM
        (
            SELECT CASE
                WHEN vTableName != 'GEONAMES' THEN CountX
                ELSE
                (
                    SELECT COUNT(DISTINCT GeoNames_ID) AS CountX
                    FROM MARKET
                )
            END AS CountX,
            ROW_NUMBER() OVER (PARTITION BY TableLookup_Name ORDER BY DateTimeX DESC) AS RN
            FROM TABLECOUNT
            WHERE TableLookup_Name = vTableName
        )
        WHERE RN = 1
    ) LOOP
        
        cHTMLFragment := cHTMLFragment || TO_CHAR(D.CountX);
        
    END LOOP;
    
    
    cHTMLFragment := cHTMLFragment || '</b>
                                    </p>
                                    <label>Columns</label>
                                    <p>
                                        <b>';
    
    FOR F IN
    (
        SELECT COUNT(*) AS CountX
        FROM USER_TAB_COLS
        WHERE Table_Name = vTableName
        AND Hidden_Column = 'NO'
        GROUP BY Table_Name
    ) LOOP
        
        cHTMLFragment := cHTMLFragment || TO_CHAR(F.CountX);
        
    END LOOP;
    
    
    cHTMLFragment := cHTMLFragment || '</b>
                                    </p>
                                    <label>Updated</label>
                                    <p>
                                        <time datetime="' || C.DateUpdated || C.TimeUpdated || '">' || C.DateUpdated || '&#x200B;' || C.TimeUpdated || '</time>
                                    </p>
                                    <label>Refresh</label>
                                    <p>' || C.TimeFrequency_Name || '</p>
                                </td>
                            </tr>
                            <tr>
                                <td>
                                    <div class="carddown grid-container">
                                        <div class="grid-50 tablet-grid-50 mobile-grid-50">
                                            <a href="' || C.URL ||  '" title="Data">
                                                <figure>
                                                    <i class="fa fa-database fa-3x"></i>
                                                </figure>
                                            </a>
                                        </div>
                                        <div class="grid-50 tablet-grid-50 mobile-grid-50">';
    
    BEGIN
        
        SELECT URL
        INTO vDDLURL
        FROM DBMS#TABLELOOKUP
        WHERE TableLookup_Name = vTableName
        AND DBMS_ID =
        (
            SELECT ID
            FROM DBMS
            WHERE Name = 'Oracle'
        );
        
        cHTMLFragment := cHTMLFragment || '
                                            <a href="' || vDDLURL || '" title="Oracle DDL">
                                                <figure>
                                                    <i class="fa fa-file-text fa-3x"></i>
                                                </figure>
                                            </a>';
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        cHTMLFragment := cHTMLFragment || '
                                            <figure>
                                                <i class="fa fa-file-text fa-3x grayscale"></i>
                                            </figure>';
        
    END;
        
        cHTMLFragment := cHTMLFragment || '
                                        </div>
                                    </div>
                                </td>
                                <td>
                                    <img id="flip" src="images/flip.svg" alt="flip" height="48" width="64" title="Flip card to preview data">
                                </td>
                            </tr>
                        </tbody>
                    </table>
                </div>
                <div class="flippable back">
                </div>
            </div>
        </div>';
    
    END LOOP;
    
    RETURN cHTMLFragment;
    
END;
/

/*
--test
SELECT TABLE_TO_HTML('countrygdp')
FROM DUAL;

SET SERVEROUTPUT ON SIZE UNLIMITED;

BEGIN
    
    FOR C IN
    (
        SELECT Name
        FROM TABLELOOKUP
        WHERE URL IS NOT NULL
        ORDER BY Name
    ) LOOP
        
        DBMS_OUTPUT.Put_Line(TABLE_TO_HTML(C.Name));
        
    END LOOP;

END;
/
*/