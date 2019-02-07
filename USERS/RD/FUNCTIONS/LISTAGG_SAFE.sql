CREATE OR REPLACE
FUNCTION LISTAGG_SAFE(gVARCHAR2Table IN VARCHAR2_TABLE, gDelimiter IN VARCHAR2 DEFAULT ',')
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    nIndex PLS_INTEGER := 0;
    vOutput VARCHAR2(32767 BYTE) := NULL;
    
BEGIN
    
    nIndex := gVARCHAR2Table.FIRST;
    
    WHILE nIndex IS NOT NULL LOOP
        
        IF nIndex = gVARCHAR2Table.FIRST THEN
            
            vOutput := gVARCHAR2Table(nIndex);
            
        ELSE
            
            vOutput := vOutput || gDelimiter || gVARCHAR2Table(nIndex);
            
        END IF;
        
        nIndex := gVARCHAR2Table.NEXT(nIndex);
        
        IF LENGTHB(vOutput) >= 4000 THEN
            
            EXIT;
            
        END IF;
        
    END LOOP;
    
    vOutput := SUBSTRB(vOutput, 1, 4000);
    
    RETURN vOutput;
    
END;
/