/*****************************************************************
 * $Author: Atanas Kebedjiev $
 *****************************************************************
 * PL/SQL code can be run as anonymous block.
 * To test, execute the whole script or create the functions and then e.g. 'select rdecode('2012') from dual;
 * Please note that task definition does not describe fully some current rules, such as
 * * subtraction - IX XC CM are the valid subtraction combinations
 * * A subtraction character cannot be repeated: 8 is expressed as VIII and not as IIX
 * * V L and D cannot be used for subtraction
 * * Any numeral cannot be repeated more than 3 times: 1910 should be MCMX and not MDCCCCX
 * Code below does not validate the Roman numeral itself and will return a result even for a non-compliant number
 * E.g. both MCMXCIX and IMM will return 1999 but the first one is the correct notation
 */
 
 SET SERVEROUTPUT ON;
 
CREATE OR REPLACE
FUNCTION ROMANNUMERALTOINTEGER(rn IN VARCHAR2)
RETURN NUMBER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    i  INTEGER;
    l  INTEGER;
    cr CHAR;   -- current Roman numeral as substring from r
    cv INTEGER; -- value of current Roman numeral
    
    gr CHAR;   -- next Roman numeral
    gv NUMBER; --  value of the next numeral;
    
    dv NUMBER; -- decimal value to return
    
BEGIN
    
    l := LENGTH(rn);
    i := 1;
    dv := 0;
    
    WHILE (i <= l) LOOP
        
        cr := SUBSTR(rn, i, 1);
        cv := ROMANSYMBOLTOINTEGER(cr);
        
        /* Look for a larger numeral in next position, like IV or CM  
        The number to subtract should be at least 1/10th of the bigger number
        CM and XC are valid, but IC and XM are not */
        IF (i < l) THEN
            
            gr := SUBSTR(rn, i+1, 1);
            gv := ROMANSYMBOLTOINTEGER(gr);
            
            IF (cv < gv ) THEN
                
                dv := dv - cv;
                
            ELSE
                
                dv := dv + cv;
                
            END IF;
            
        ELSE
            
            dv := dv + cv;
            
        END IF;  -- need to add the last value unconditionally
        
        i := i + 1;
        
    END LOOP;
    
    RETURN dv;
    
END;
/
 
BEGIN
 
    DBMS_OUTPUT.PUT_LINE ('MMXII      = ' || ROMANNUMERALTOINTEGER('MMXII'));       -- 2012
    DBMS_OUTPUT.PUT_LINE ('MCMLI      = ' || ROMANNUMERALTOINTEGER('MCMLI'));       -- 1951
    DBMS_OUTPUT.PUT_LINE ('MCMLXXXVII = ' || ROMANNUMERALTOINTEGER('MCMLXXXVII'));  -- 1987
    DBMS_OUTPUT.PUT_LINE ('MDCLXVI    = ' || ROMANNUMERALTOINTEGER('MDCLXVI'));     -- 1666
    DBMS_OUTPUT.PUT_LINE ('MCMXCIX    = ' || ROMANNUMERALTOINTEGER('MCMXCIX'));     -- 1999
 
END;
/