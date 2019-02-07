CREATE OR REPLACE
FUNCTION HTML_ADD_CLASS_STYLE(gXMLType XMLTYPE)
RETURN XMLTYPE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    lStyleFragment CLOB := EMPTY_CLOB();
    lXMLType XMLTYPE;
    
BEGIN
    
    lXMLType := gXMLType;
    
    FOR C IN
    (
        SELECT Class,
        'tr.' || Class || ' {background-color:' || HTMLColor_Name || '}' AS XMLFragment,
        ROW_NUMBER() OVER (ORDER BY Class) AS RN,
        COUNT(*) OVER () AS Cnt
        FROM HTMLCLASSSTYLE
        ORDER BY Class
    ) LOOP
        
        IF C.RN = 1 THEN
            
            lStyleFragment := '<style type="text/css">';
            
        END IF;
        
        lStyleFragment := lStyleFragment || CHR(10) || C.XMLFragment;
        
        IF C.RN = C.Cnt THEN
            
            lStyleFragment := lStyleFragment || CHR(10) || '</style>';
            
        END IF;
        
        SELECT INSERTCHILDXML
        (
            lXMLType,
            --The column to be updated
            '//table/tbody/tr[td="' || REPLACE(UPPER(C.Class), '_', ' ') || '"]',
            --The XPath where the insert has to take place
            '@class',
            --The element name that needs to be inserted 
            C.Class
        )
        INTO lXMLType
        FROM DUAL;
        
    END LOOP;
    
    SELECT INSERTCHILDXML
    (
        lXMLType,
        '//head',
        'style',
        XMLPARSE(DOCUMENT lStyleFragment WELLFORMED)
    )
    INTO lXMLType
    FROM DUAL;
    
    RETURN lXMLType;

END;
/

GRANT EXECUTE ON HTML_ADD_CLASS_STYLE TO PUBLIC;

/*
--test
SET DEFINE OFF;

SELECT XMLSERIALIZE
(
    DOCUMENT HTML_ADD_CLASS_STYLE
    (
        XMLPARSE
        (
            DOCUMENT '<html lang="en">
  <head>
    <title>GBRONSRGC 2015-10-23T20:18:20</title>
    <base target="_blank"/>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <meta name="format-detection" content="telephone=no"/>
  </head>
  <body>
    <table border="1">
      <thead>
        <tr>
          <th>Time</th>
          <th>Action</th>
          <th>Object name</th>
          <th>Detail</th>
          <th>Outcome</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>20:18:21</td>
          <td>FIND_URL_ON_WEB_PAGE</td>
          <td>Register_of_Geographic_Codes</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:21</td>
          <td>INSERT</td>
          <td>INBOUND</td>
          <td>https://geoportal.statistics.gov.uk/Docs/Latest%20Products/Register_of_Geographic_Codes_(Sep_2015).zip</td>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:21</td>
          <td>COMMIT</td>
          <td>RD</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:21</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>INBOUND</td>
          <td>1</td>
        </tr>
        <tr>
          <td>20:18:21</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>S_GBRONSRGC</td>
          <td>1</td>
        </tr>
        <tr>
          <td>20:18:22</td>
          <td>COMMIT</td>
          <td>RD</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:22</td>
          <td>MERGE</td>
          <td>GBRONSRGC</td>
          <td/>
          <td>2</td>
        </tr>
        <tr>
          <td>20:18:22</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>GBRONSRGC</td>
          <td>1</td>
        </tr>
        <tr>
          <td>20:18:22</td>
          <td>COMMIT</td>
          <td>RD</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:22</td>
          <td>GATHER STATS</td>
          <td>GBRONSRGC</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>20:18:23</td>
          <td>REFRESH</td>
          <td>GOOGLE</td>
          <td>GBRONSRGC</td>
          <td>
2015-10-23T20:18:24 {
  &quot;kind&quot; : &quot;fusiontables#sqlresponse&quot;,
  &quot;columns&quot; : [&quot;affected_rows&quot;],
  &quot;rows&quot; : [[&quot;145&quot;]]
}
2015-10-23T20:18:34 Updated attribution
2015-10-23T20:18:52 Updated column descriptions
2015-10-23T20:18:52 Count(*): 145</td>
        </tr>
      </tbody>
    </table>
  </body>
</html>'
        )
    ) AS CLOB INDENT SIZE = 2
) AS HTML
FROM DUAL
;
*/