CREATE OR REPLACE
PROCEDURE TOUCH
(
    gTable_Name IN TABLELOOKUP.Name%TYPE,
    gDateTimeReference IN DATE DEFAULT SYSDATE_UTC
)
AS
    
    c SYS_REFCURSOR;
    nCount INTEGER := 0;
    vTable_Name TABLELOOKUP.Name%TYPE := ORACLE_NAME(gTable_Name);
    
BEGIN
    
    
    SELECT COUNT(*)
    INTO nCount
    FROM TABLELOOKUP
    WHERE Name = vTable_Name;
    
    
    IF nCount > 0 THEN
        
        UPDATE
        TABLELOOKUP
        SET DateTimeUpdated = gDateTimeReference
        WHERE Name = vTable_Name;
        
        UPDATE
        TABLELOOKUP
        SET DateTimeUpdated = SYSDATE_UTC
        WHERE Name = 'TABLELOOKUP';
        
        IF vTable_Name != 'S_TOWNNAME' THEN
            
            --EXECUTE IMMEDIATE does not seem to handle hints
            OPEN c FOR 'SELECT /*+ FULL(' || vTable_Name || ') */ COUNT(*) AS CountX FROM "' || vTable_Name || '"';
            
            LOOP
                
                FETCH c INTO nCount;
                EXIT WHEN c%NOTFOUND;
                
            END LOOP;
            
            CLOSE c;
            
        ELSE
            
            SELECT /*+ FULL(S_TOWNNAME) */
            COUNT(*) AS CountX
            INTO nCount
            FROM S_TOWNNAME;
            
        END IF;
        
        MERGE
        INTO TABLECOUNT X
        USING
        (
            SELECT vTable_Name AS TableLookup_Name,
            gDateTimeReference AS DateTimeX,
            nCount AS CountX
            FROM DUAL
        ) Y
            ON (X.TableLookup_Name = Y.TableLookup_Name
                    AND X.DateTimeX = Y.DateTimeX)
        WHEN NOT MATCHED THEN INSERT
        (
            TABLELOOKUP_NAME,
            DATETIMEX,
            COUNTX
        )
        VALUES
        (
            Y.TableLookup_Name,
            Y.DateTimeX,
            Y.CountX
        )
        WHEN MATCHED THEN UPDATE SET X.CountX = Y.CountX;
        
    ELSE
        
        DBMS_OUTPUT.Put_Line(vTable_Name || ' is not in TABLELOOKUP');
        
    END IF;
    
    
END;
/

/*
--test
SET SERVEROUTPUT ON;

BEGIN
    
    TOUCH
    (
        'COMPANYREGISTER'/*,
        CAST
        (
            SYS_EXTRACT_UTC
            (
                FROM_TZ
                (
                    CAST
                    (
                        TO_DATE('2015-01-09T23:22:06', 'YYYY-MM-DD"T"HH24:MI:SS')
                        AS TIMESTAMP
                    ),
                    'Europe/London'
                )
            ) AS DATE
        )*//*
    );
    
    COMMIT;
    
END;
/

--All table counts
SET SERVEROUTPUT ON;

BEGIN
    
    FOR C IN
    (
        SELECT Name AS TableLookup_Name
        FROM TABLELOOKUP
        WHERE (Comments != 'Reserved' OR Comments IS NULL)
        ORDER BY ID
    ) LOOP
        
        TOUCH(C.TableLookup_Name);
        
    END LOOP;
    
    COMMIT;
    
END;
/
*/