SET DEFINE OFF;
SET SERVEROUTPUT ON;

CREATE OR REPLACE
PROCEDURE CLOB_TO_FILE
(
    gCLOB IN CLOB,
    gDirectory IN VARCHAR2,
    gFileName IN VARCHAR2,
    gOpen_Mode IN CHAR DEFAULT 'w'
)
AUTHID CURRENT_USER
AS
    
    l_output UTL_FILE.File_Type;
    l_amt NUMBER := 8000; --~32767/4 bytes per character in UTF-8
    l_offset NUMBER := 1;
    l_length NUMBER := COALESCE
    (
        DBMS_LOB.GetLength(gCLOB),
        0
    );
    
BEGIN
    
    l_output := UTL_FILE.FOpen(gDirectory, gFileName, gOpen_Mode, 32767);
    
    IF UTL_FILE.Is_Open(l_output) THEN
        
        WHILE ( l_offset < l_length )
        LOOP
            
            UTL_FILE.Put(l_output, DBMS_LOB.Substr(gCLOB, l_amt, l_offset));
            
            UTL_FILE.FFlush(l_output);
            
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

GRANT EXECUTE ON CLOB_TO_FILE TO PUBLIC;

/*
--test
SET SERVEROUTPUT ON;

DECLARE
    
    cCLOB CLOB := EMPTY_CLOB();
    
BEGIN
    
    SELECT A.Data
    INTO cCLOB
    FROM INBOUND A
    WHERE A.TableLookup_Name = 'GEONAMESFEATURECODE'
    --AND A.URL LIKE 'http://download.geonames.org/export/dump/deletes-2013-05-14%'
    AND A.DateTimeX =
    (
        SELECT MAX(B.DateTimex)
        FROM INBOUND B
        WHERE A.TableLookup_Name = B.TableLookup_Name
        --AND B.URL LIKE 'http://download.geonames.org/export/dump/deletes-2013-05-14%'
    );
    
    CLOB_TO_FILE(cCLOB, 'RD', 'S_GEONAMESFEATURECODE.tsv');
    
END;
/

BEGIN
    
    UTL_FILE.FREMOVE('RD', 'S_GEONAMES_D.txt');
    
END;
/
--appending XML to file
SET SERVEROUTPUT ON;

BEGIN
    
    FOR C IN
    (
        
    ) LOOP
        
        CLOB_TO_FILE(C.XML.getClobVal(), 'RD', 'test.xml', 'a');
        
    END LOOP;
    
END;
/
*/