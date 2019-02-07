--Update sequences whose Last_Number is below the MAX(ID) of the associated table
CREATE OR REPLACE
PROCEDURE UPDATE_SEQUENCE
(
    gTable_Name IN VARCHAR2 DEFAULT NULL,
    --1 if you just want the comparison with no update of the sequence if not matched
    gObserver IN INTEGER DEFAULT 1,
    gSuffix IN VARCHAR2 DEFAULT '_SEQ'
)
AUTHID CURRENT_USER
AS
    
    bObserver	BOOLEAN := CASE gObserver
        WHEN 1 THEN TRUE
        ELSE FALSE
    END;
    vSuffix VARCHAR2(29 CHAR) := ORACLE_NAME(gSuffix);
    
    --Cursor variables
    TYPE CurStmt IS REF CURSOR;
    vLoopStmt VARCHAR2(4000 BYTE) := '';
    C0 CurStmt;
    vStmt VARCHAR2(4000 BYTE) := '';
    C1 CurStmt;
    
    --Program variables
    nMax PLS_INTEGER := 0;
    vStatus VARCHAR2(15 BYTE) := '';
    nNextVal PLS_INTEGER := 0;
    XTable_Name VARCHAR2(30 BYTE) := '';
    XColumn_Name VARCHAR2(30 BYTE) := '';
    XIncrement_By INTEGER := 0;
    XLast_Number INTEGER := 0;
    
    --Error handling variables
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.PUT_LINE('Table name' || CHR(9) || 'MAX(SeqNo)' || CHR(9) || 'Last number' || CHR(9) || 'Status');
    
    vLoopStmt := 'SELECT UT.Table_Name
, UCC.Column_Name
, US.Increment_By
, US.Last_Number
FROM USER_TABLES UT
INNER JOIN USER_SEQUENCES US
    ON SUBSTR(UT.Table_Name, 1, 26) || ''' || ORACLE_NAME(vSuffix) || ''' = US.Sequence_Name
INNER JOIN USER_CONSTRAINTS UC
    ON UT.Table_Name = UC.Table_Name
INNER JOIN USER_CONS_COLUMNS UCC
    ON UC.Constraint_Name = UCC.Constraint_Name
WHERE UT.Table_Name = ' || CASE WHEN ORACLE_NAME(gTable_Name) IS NULL THEN 'UT.Table_Name' ELSE '''' || ORACLE_NAME(gTable_Name) || '''' END || '
AND UC.Constraint_Type IN (''P'', ''U'')
AND UC.Constraint_Name NOT IN --Exclude multi-column constraints
(SELECT Constraint_Name FROM USER_CONS_COLUMNS WHERE Position != 1)
AND UCC.Column_Name = ''ID''
ORDER BY UT.Table_Name';

    OPEN C0 FOR vLoopStmt;
    
    LOOP
    FETCH C0 INTO XTable_Name
    , XColumn_Name
    , XIncrement_By
    , XLast_Number;
    EXIT WHEN C0%NOTFOUND;
        
        vStmt := 'SELECT COALESCE(MAX(' || XColumn_Name || '), 0) FROM ' || XTable_Name;
        
        OPEN C1 FOR vStmt;
        
        LOOP
        FETCH C1 INTO nMax; 
        EXIT WHEN C1%NOTFOUND;
            
            IF nMax <= XLast_Number THEN
            
                vStatus := 'Pass';
            
            ELSE
                
                IF bObserver THEN
                    
                    vStatus := 'MISMATCH';
                    
                ELSE
                    
                    SET_SEQ_TO
                    (
                        SUBSTRB(XTable_Name, 1, 26) || vSuffix,
                        nMax
                    );
                    
                    vStatus := 'Updated';
                    
                END IF; --End if observing
                
            END IF; --Ending equivalence test
            
            DBMS_OUTPUT.Put_Line(XTable_Name || CHR(9) || nMax || CHR(9) || XLast_Number || CHR(9) || vStatus);
            
        END LOOP; --Ending fetch loop
        
    END LOOP; --Ending main loop
    
    
    CLOSE C1;
    
    CLOSE C0;
    

EXCEPTION
WHEN OTHERS THEN

    vError := SUBSTRB(SQLERRM, 1, 255);
    
    DBMS_OUTPUT.Put_Line(vError);
    
    ROLLBACK;
    
    DBMS_OUTPUT.Put_Line('ROLLBACK processed');

END;
/

GRANT EXECUTE ON UPDATE_SEQUENCE TO PUBLIC;

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    UPDATE_SEQUENCE('PERSON', 0);
    
END;
/
*/