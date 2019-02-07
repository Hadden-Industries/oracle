CREATE OR REPLACE 
PACKAGE BODY RD_HTF
AS
    
    --Global package variables
    
    FUNCTION SPAN
    (
        ctext IN VARCHAR2,
        cattributes IN VARCHAR2 DEFAULT ''
    )
    RETURN VARCHAR2
    DETERMINISTIC PARALLEL_ENABLE
    AS
        
        PRAGMA UDF;
        
    BEGIN
        
        RETURN '<span' || CASE
            WHEN cattributes IS NOT NULL THEN ' ' || cattributes
            ELSE ''
        END  || '>' || ctext || '</span>';
        
    END SPAN;
    
    
    FUNCTION TIME
    (
        ctext IN VARCHAR2,
        cdatetime IN VARCHAR2 DEFAULT NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC PARALLEL_ENABLE
    AS
        
        PRAGMA UDF;
        
    BEGIN
        
        RETURN '<time' || CASE
            WHEN cdatetime IS NOT NULL THEN ' datetime="' || cdatetime || '"'
            ELSE ''
        END  || '>' || ctext || '</time>';
        
    END TIME;
    
    
    FUNCTION TIME
    (
        ctext IN VARCHAR2,
        gDateTimeUTC IN DATE DEFAULT NULL
    )
    RETURN VARCHAR2
    DETERMINISTIC PARALLEL_ENABLE
    AS
        
        PRAGMA UDF;
        
        vReturn VARCHAR2(4000 BYTE);
        
    BEGIN
        
        SELECT TIME
        (
            ctext => ctext,
            cdatetime => TO_CHAR(gDateTimeUTC, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        )
        INTO vReturn
        FROM DUAL;
        
        RETURN vReturn;
        
    END TIME;
    
END;
/