--Source: https://community.oracle.com/message/2016458#2016458

CREATE OR REPLACE
FUNCTION SPLIT
(
    gList VARCHAR2,
    gDelimiter VARCHAR2 DEFAULT ',',
    gID VARCHAR2 DEFAULT '1'
)
RETURN Split_Table PIPELINED
DETERMINISTIC
AS
    
    PRAGMA UDF;
    
    nIndex SIMPLE_INTEGER := 0;
    rSPLIT_TYPE SPLIT_TYPE := SPLIT_TYPE(gID, 1, NULL);
    vList VARCHAR2(32767 BYTE) := gList;
    
BEGIN
    
    IF gList IS NOT NULL THEN
        
        LOOP
            
            nIndex := INSTR(vList, gDelimiter);
            
            IF nIndex > 0 THEN
                
                rSPLIT_TYPE.Text := SUBSTR(vList, 1, nIndex - 1);
                
                PIPE ROW(rSPLIT_TYPE);
                
                vList := SUBSTR(vList, nIndex + LENGTH(gDelimiter));
                
                --If there is a trailing delimiter, return
                IF vList IS NULL
                    
                    THEN RETURN;
                    
                END IF;
                
                rSPLIT_TYPE.Text := vList;
                
                rSPLIT_TYPE.Position := rSPLIT_TYPE.Position + 1;
                
            ELSE
                
                rSPLIT_TYPE.Text := vList;
                
                PIPE ROW(rSPLIT_TYPE);
                
                EXIT;
                
            END IF;
            
        END LOOP;
        
    END IF;
    
    RETURN;
    
END;
/

/*
--test
SELECT *
FROM TABLE(SPLIT(NULL));

SELECT *
FROM TABLE(SPLIT('''11122'''));

SELECT Position,
TRIM(Text) AS Text
FROM TABLE(SPLIT('''11122'', ''61245'', ''62192'', ''63975'', ''63981'', ''63824'', ''63976'', ''63978'''));

--test trailing delimiter
SELECT Position,
TRIM(Text) AS Text
FROM TABLE(SPLIT('11122, 61245, 62192, 63975, 63981, 63824, 63976, 63978,'));
*/