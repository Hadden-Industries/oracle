CREATE OR REPLACE
PROCEDURE DROP_JAVA(gObject_Name IN VARCHAR2)
AS
    
    CURSOR curs1 IS
    SELECT Object_Name,
    Object_Type
    FROM USER_OBJECTS
    WHERE Object_Name = DBMS_JAVA.ShortName(gObject_Name)
    ORDER BY CASE Object_Type
        WHEN 'JAVA SOURCE' THEN 1
        WHEN 'JAVA CLASS' THEN 2
        ELSE 3
    END;
    
    ONAME VARCHAR2(30 BYTE);
    OTYPE VARCHAR2(30 BYTE);
    
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN

    open curs1;
    fetch curs1 into ONAME, OTYPE;
    
    if curs1%notfound then
        
        return;
        
    else
        
        if OTYPE='JAVA CLASS' THEN
            
            execute immediate 'DROP JAVA CLASS "' || ONAME || '"';
            
        ELSIF OTYPE='JAVA SOURCE' THEN
            
            execute immediate 'DROP JAVA SOURCE "' || ONAME || '"';
            
        ELSE
            
            execute immediate 'DROP JAVA RESOURCE "' || ONAME || '"';
            
        end if;
        
    end if;
    
EXCEPTION
WHEN OTHERS THEN
    
    vError := SUBSTRB(SQLErrM, 1, 255);
    
    DBMS_OUTPUT.Put_Line(vError);
    
    if OTYPE = 'JAVA CLASS' then
    
        ONAME := DBMS_JAVA.derivedFrom(ONAME, USER, 'CLASS');
        execute immediate 'DROP JAVA SOURCE "' || ONAME || '"';
        
    end if; 
    
    CLOSE curs1;

END;
/

/*
--test
SET SERVEROUTPUT ON;

BEGIN
    
    DROP_JAVA('com/google/common/collect/ConcurrentHashMultiset');
    
END;
/

--Drop all java objects
SET SERVEROUTPUT ON;

BEGIN
    
    FOR C IN
    (
        SELECT DBMS_JAVA.LongName(Object_Name) AS Object_Name
        FROM USER_OBJECTS
        WHERE Object_Type LIKE 'JAVA%'
        ORDER BY 1
    ) LOOP
        
        DROP_JAVA(C.Object_Name);
        
    END LOOP;
    
END;
/
*/