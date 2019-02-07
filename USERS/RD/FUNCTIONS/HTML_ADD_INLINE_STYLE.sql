CREATE OR REPLACE
FUNCTION HTML_ADD_INLINE_STYLE(gXMLType XMLTYPE)
RETURN XMLTYPE
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    lXMLType XMLTYPE;
    
BEGIN
    
    lXMLType := gXMLType;
    
    FOR C IN
    (
        SELECT Class,
        'background-color:' || HTMLColor_Name AS Style,
        ROW_NUMBER() OVER (ORDER BY Class) AS RN,
        COUNT(*) OVER () AS Cnt
        FROM HTMLCLASSSTYLE
        ORDER BY Class
    ) LOOP
        
        SELECT INSERTCHILDXML
        (
            lXMLType,
            --The column to be updated
            '//table/tbody/tr[td="' || REPLACE(UPPER(C.Class), '_', ' ') || '"]',
            --The XPath where the insert has to take place
            '@style',
            --The element name that needs to be inserted 
            C.Style
        )
        INTO lXMLType
        FROM DUAL;
        
    END LOOP;
    
    RETURN lXMLType;

END;
/

/*
--test

SELECT XMLSERIALIZE
(
    DOCUMENT HTML_ADD_INLINE_STYLE
    (
        XMLPARSE
        (
            DOCUMENT '<html lang="en">
  <head>
    <title>GEONAMES 2016-04-25T10:06:00</title>
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
          <td>10:06:01</td>
          <td>COMMIT</td>
          <td>RD</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>INBOUND</td>
          <td>1</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>S_GEONAMESALTNAME_D</td>
          <td>1</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>MERGE</td>
          <td>GEONAMES</td>
          <td/>
          <td>189</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>MERGE</td>
          <td>GEONAMESALTNAME</td>
          <td/>
          <td>61</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>DELETE</td>
          <td>GEONAMESALTNAME</td>
          <td/>
          <td>0</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>DELETE</td>
          <td>GEONAMES</td>
          <td/>
          <td>0</td>
        </tr>
        <tr>
          <td>10:06:01</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>GEONAMES</td>
          <td>1</td>
        </tr>
        <tr>
          <td>10:06:02</td>
          <td>UPDATE</td>
          <td>TABLELOOKUP</td>
          <td>GEONAMESALTNAME</td>
          <td>1</td>
        </tr>
        <tr>
          <td>10:06:02</td>
          <td>COMMIT</td>
          <td>RD</td>
          <td/>
          <td>✓</td>
        </tr>
        <tr>
          <td>10:06:02</td>
          <td>REFRESH</td>
          <td>S_TOWNNAME</td>
          <td/>
          <td>✓</td>
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