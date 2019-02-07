SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
FUNCTION GET_OBJECT_SIZE(gObjectName IN VARCHAR2)
RETURN NUMBER
AUTHID CURRENT_USER
AS
    
    nSize NUMBER := 0;
    
    vIOT_Type ALL_TABLES.IOT_Type%TYPE := '';
    vIndex_Name ALL_INDEXES.Index_Name%TYPE := '';
    vObject_Name ALL_OBJECTS.Object_Name%TYPE := ORACLE_NAME(gObjectName);
    vObject_Type ALL_OBJECTS.Object_Type%TYPE := '';
    
BEGIN
    
    
    BEGIN
        
        SELECT Object_Type
        INTO vObject_Type
        FROM
        (
            SELECT Object_Type,
            --Prioritise tables (e.g. over Materialised Views)
            ROW_NUMBER() OVER
            (
                ORDER BY CASE Object_Type
                    WHEN 'TABLE' THEN 0
                    ELSE 1
                END
            ) AS RN
            FROM ALL_OBJECTS
            WHERE Object_Name = vObject_Name
        )
        WHERE RN = 1;
        
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
        
        BEGIN
            --Attempt to find tablespace with this name
            SELECT 'TABLESPACE' AS Object_Type
            INTO vObject_Type
            FROM USER_TABLESPACES
            WHERE Tablespace_Name = vObject_Name;
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            RETURN -1;
            
        END;
        
    END;
    
    
    IF vObject_Type = 'TABLE' THEN
        
        SELECT IOT_Type
        INTO vIOT_Type
        FROM ALL_TABLES
        WHERE Table_Name = vObject_Name;
        
    ELSIF vObject_Type = 'TABLESPACE' THEN
        
        SELECT SUM(Bytes/1024/1024)
        INTO nSize
        FROM USER_SEGMENTS 
        WHERE Tablespace_Name = vObject_Name
        GROUP BY Tablespace_Name;
        
        RETURN ROUND(nSize, 2);
        
    END IF;
    
    
    IF vIOT_Type = 'IOT' THEN
        
        SELECT Index_Name
        INTO vIndex_Name
        FROM ALL_INDEXES
        WHERE Table_Name = vObject_Name
        AND Index_Type = 'IOT - TOP';
        
    END IF;
    
    
    SELECT SUM(Bytes)/(1024*1024)
    INTO nSize
    FROM USER_SEGMENTS
    WHERE Segment_Name = COALESCE(vIndex_Name, vObject_Name)
    GROUP BY Segment_Name;
    
    
    RETURN ROUND(nSize, 2);
    
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

SELECT RD.GET_OBJECT_SIZE('GEONAMES')
FROM DUAL;
*/