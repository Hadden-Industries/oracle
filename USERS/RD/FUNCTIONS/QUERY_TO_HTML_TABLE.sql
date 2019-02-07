CREATE OR REPLACE
FUNCTION QUERY_TO_HTML_TABLE(gQuery VARCHAR2)
RETURN XMLTYPE
PARALLEL_ENABLE DETERMINISTIC
AS
    
    uContext DBMS_XMLGEN.ctxHandle;
    xXML XMLTYPE;
    xXSLT XMLTYPE;
    
BEGIN
    
    uContext := DBMS_XMLGEN.NewContext(gQuery);
    
    DBMS_XMLGEN.SetNULLHandling(uContext, DBMS_XMLGEN.Empty_Tag); 
    
    xXML := DBMS_XMLGEN.GetXMLType(uContext);
    
    SELECT XML
    INTO xXSLT
    FROM XSLT
    WHERE Name = 'ORACLE_XML_TO_HTML_TABLE_STRIPED';
    
    RETURN xXML.Transform(xXSLT);
    
END;
/

/*
--test
SELECT QUERY_TO_HTML_TABLE
(
    'SELECT ID AS "Alpha3",
    Parent$Country_ID AS "Parent_Alpha3",
    Name,
    Alpha2
    FROM COUNTRY'
)
FROM DUAL;

SELECT XMLSERIALIZE
(
    DOCUMENT QUERY_TO_HTML_TABLE
    (
        'SELECT *
        FROM COUNTRYSUBDIV
        WHERE Country_ID = ''CYP'''
    ) AS CLOB INDENT SIZE=2
) AS XML
FROM DUAL;
*/