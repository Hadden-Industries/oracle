CREATE OR REPLACE
PROCEDURE MOVE_TABLELOOKUP_ID
(
    gTableLookup_Name IN TABLELOOKUP.Name%TYPE,
    gUp IN INTEGER DEFAULT 1
)
AS

BEGIN
    
    UPDATE TABLELOOKUP
    SET ID =
    (
        ID
        +
        CASE
            WHEN gUp = 1 THEN 1
            ELSE -1
        END
    )
    WHERE ID >=
    (
        SELECT ID
        FROM TABLELOOKUP
        WHERE Name = gTableLookup_Name
    );
    
END;
/

/*
--test
BEGIN
    
    MOVE_TABLELOOKUP_ID
    (
        gTableLookup_Name=>'USCOUNTRYSUBDIV',
        gUp=>1
    );
    
    COMMIT;
    
END;
/
*/