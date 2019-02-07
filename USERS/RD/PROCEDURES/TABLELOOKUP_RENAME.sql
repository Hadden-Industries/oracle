CREATE OR REPLACE
PROCEDURE TABLELOOKUP_RENAME(gFrom$TableLookup_Name IN TABLELOOKUP.Name%TYPE, gTo$TableLookup_Name IN TABLELOOKUP.Name%TYPE)
AS
    
    vError VARCHAR2(500 BYTE) := '';
    vFrom$TableLookup_Name TABLELOOKUP.Name%TYPE := SUBSTRB(REGEXP_REPLACE(UPPER(gFrom$TableLookup_Name), '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#_]', ''), 1, 30);
    vTo$TableLookup_Name TABLELOOKUP.Name%TYPE := SUBSTRB(REGEXP_REPLACE(UPPER(gTo$TableLookup_Name), '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789$#_]', ''), 1, 30);
    
BEGIN
    
    UPDATE TABLELOOKUP
    SET Name = vTo$TableLookup_Name,
    NameMedialCapital = vTo$TableLookup_Name,
    NamePluralised = vTo$TableLookup_Name
    WHERE Name = vFrom$TableLookup_Name;
    
    FOR C IN
    (
        SELECT Table_Name
        FROM USER_CONSTRAINTS A
        WHERE A.R_Constraint_Name =
        (
            SELECT Constraint_Name
            FROM USER_CONSTRAINTS
            WHERE Constraint_Name IN
            (
                SELECT Constraint_Name
                FROM USER_CONS_COLUMNS
                WHERE Table_Name = 'TABLELOOKUP'
                AND Column_Name = 'NAME'
            )
            AND Constraint_Type = 'U'
        )
        AND A.Constraint_Type = 'R'
    ) LOOP
        
        EXECUTE IMMEDIATE('UPDATE ' || C.Table_Name || '
SET TableLookup_Name = ''' || vTo$TableLookup_Name || '''
WHERE TableLookup_Name = ''' || vFrom$TableLookup_Name || '''');
        
    END LOOP;
    
EXCEPTION
WHEN OTHERS THEN
    
    vError := SUBSTRB(SQLErrM, 1, 255);
    
    DBMS_OUTPUT.Put_Line(vError);
    
    ROLLBACK;
    
END;
/

/*
--test
SET SERVEROUTPUT ON;

BEGIN
    
    TABLELOOKUP_RENAME('FXRATE_UNIQUE', 'UNIQUE$FXRATE');
    
END;
/

COMMIT;
*/
