CREATE OR REPLACE
FUNCTION IS_XML
(
    gText IN CLOB,
    gDBMS_OUTPUT IN INTEGER DEFAULT 0
)
RETURN NUMBER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    p XMLPARSER.parser;
    
BEGIN    
    
    p := XMLPARSER.newParser;
    
    XMLPARSER.parseClob(p, gText);
    
    RETURN 1;
    
EXCEPTION
WHEN OTHERS THEN
    
    IF gDBMS_OUTPUT = 1 THEN
        
        DBMS_OUTPUT.Enable;
        DBMS_OUTPUT.Put_Line
        (
            SUBSTRB(SQLErrM, 1, 255)
        );
        
    END IF;
    
    RETURN 0;
    
END;
/

/*
--test
SELECT IS_XML()
FROM DUAL;
*/