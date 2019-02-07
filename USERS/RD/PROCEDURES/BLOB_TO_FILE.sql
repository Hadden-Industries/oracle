SET DEFINE OFF;
SET SERVEROUTPUT ON;

CREATE OR REPLACE
PROCEDURE BLOB_TO_FILE
(
    gBLOB IN BLOB,
    gDirectory IN VARCHAR2,
    gFileName IN VARCHAR2,
    gOpen_Mode IN CHAR DEFAULT 'wb'
)
AUTHID CURRENT_USER
AS
    
    l_output UTL_FILE.File_Type;
    l_amt NUMBER := 32767;
    l_offset NUMBER := 1;
    l_length NUMBER := COALESCE(DBMS_LOB.GetLength(gBLOB), 0);
    
BEGIN
    
    l_output := UTL_FILE.FOpen(gDirectory, gFileName, gOpen_Mode, 32767);
    
    IF UTL_FILE.Is_Open(l_output) THEN
    
        WHILE ( l_offset < l_length )
        LOOP
        
            UTL_FILE.Put_Raw(l_output, DBMS_LOB.Substr(gBLOB, l_amt, l_offset), TRUE);
            
            l_offset := l_offset + l_amt;
            
        END LOOP;
    
    END IF;
    
    UTL_FILE.FClose(l_output);
    
EXCEPTION
WHEN OTHERS THEN
    
    -- Close the file if something goes wrong.
    IF UTL_FILE.Is_Open(l_output) THEN
    
        UTL_FILE.FClose(l_output);
        
    END IF;
    
END;
/

GRANT EXECUTE ON BLOB_TO_FILE TO PUBLIC;

--test
/*
SET SERVEROUTPUT ON;

DECLARE
    
    cBLOB CLOB := EMPTY_CLOB();
    
BEGIN
    
    SELECT A.Data
    INTO cCLOB
    FROM INBOUND A
    WHERE A.TableLookup_Name = 'GEONAMES'
    AND A.URL LIKE 'http://download.geonames.org/export/dump/deletes-2013-05-14%'
    AND A.DateTimeX = (SELECT MAX(B.DateTimex)
    FROM INBOUND B
    WHERE A.TableLookup_Name = B.TableLookup_Name
    AND B.URL LIKE 'http://download.geonames.org/export/dump/deletes-2013-05-14%')
    ;
    
    CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMES_D.txt');
    
END;
/

BEGIN
    
    UTL_FILE.FREMOVE('RD', 'S_GEONAMES_D.txt');
    
END;
/
*/