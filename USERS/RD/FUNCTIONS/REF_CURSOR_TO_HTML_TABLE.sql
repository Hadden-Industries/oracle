CREATE OR REPLACE
FUNCTION REF_CURSOR_TO_HTML_TABLE(gQuery SYS_REFCURSOR)
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
SET SERVEROUTPUT ON;

DECLARE
    
    vMsg CLOB := EMPTY_CLOB();
    sCursor SYS_REFCURSOR;
    
BEGIN
    
    DBMS_OUTPUT.Enable(NULL);
    
    OPEN sCursor FOR
    SELECT *
    FROM COUNTRYSUBDIV
    WHERE Country_ID = 'CYP';
    
    vMsg := REF_CURSOR_TO_HTML_TABLE(sCursor).GetClobVal();
    
    DBMS_OUTPUT.Put_Line(vMsg);
    
    CLOSE sCursor;
    
END;
/
*/