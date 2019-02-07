SET SERVEROUTPUT ON;

CREATE OR REPLACE
FUNCTION TABLE_TO_HTML_CHUNKS
(
    gQuery IN VARCHAR2,
    gIncludeHeader IN INTEGER DEFAULT 0
)
RETURN HTTP_CHUNKS PIPELINED
DETERMINISTIC
AS
    
    gCursor INTEGER := DBMS_SQL.Open_Cursor;
    Desc_Tab DBMS_SQL.Desc_Tab;
    
    rHTTP_CHUNK HTTP_CHUNK := HTTP_CHUNK(0, NULL, NULL);
    
    vColumnValue VARCHAR2(4000 BYTE) := '';
    nColumns INTEGER := 0;
    vSeparator VARCHAR2(1 BYTE) := ',';
    nRows INTEGER := 0;
    cLine CLOB;
    
    cColumnValue CLOB;
    nChunkStart PLS_INTEGER := 1;
    vChunk VARCHAR2(4000 BYTE) := '';
    
    vDBMSDataType_Name DBMSDATATYPE.Name%TYPE := '';
    vPKColumnList VARCHAR2(4000 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.Enable;
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => cColumnValue,
        cache => TRUE,
        dur => DBMS_LOB.Call
    );
    
    DBMS_LOB.Open(cColumnValue, DBMS_LOB.LOB_ReadWrite);
    
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => cLine,
        cache => TRUE,
        dur => DBMS_LOB.Call
    );
    
    DBMS_LOB.Open(cLine, DBMS_LOB.LOB_ReadWrite);
    
    --
    -- Set up an exception block
    --
    DECLARE
        
        invalid_type EXCEPTION;
        
    BEGIN
    -- 
    -- Parse and describe the query. We reset the descTbl to an empty table so .count on it will be reliable.
    --
    DBMS_SQL.Parse(gCursor, gQuery, DBMS_SQL.Native);
    
    DBMS_SQL.Describe_Columns(gCursor, nColumns, Desc_Tab);
    --
    -- Verify that the table contains supported columns
    --
    FOR i IN 1 .. Desc_Tab.Count LOOP
        
        SELECT A.Name
        INTO vDBMSDataType_Name
        FROM DBMSDATATYPE A
        INNER JOIN DBMS B
            ON A.DBMS_ID = B.ID
        WHERE A.Code = Desc_Tab(i).Col_Type
        AND B.Name = 'Oracle';
        
        IF vDBMSDataType_Name IN
        (
            'CHAR',
            'DATE',
            'LONG',
            'NUMBER',
            'RAW',
            'TIMESTAMP',
            'VARCHAR2'
        ) THEN
            
            --Bind every single column to a VARCHAR2(4000 BYTE). We don't care if we are fetching a number or a date or whatever. Everything can be a string.
            DBMS_SQL.Define_Column(gCursor, i, vColumnValue, 4000);
            
        ELSIF vDBMSDataType_Name = 'CLOB' THEN
            
            DBMS_SQL.Define_Column(gCursor, i, cColumnValue);
            
        ELSE
            
            DBMS_OUTPUT.Put_Line('Column ' || TO_CHAR(i) || ' has unsupported data type of ' || vDBMSDataType_Name);
            
            RAISE invalid_type;
            
        END IF;
        
    END LOOP;
    --
    -- Run the query - ignore the output of execute. It is only valid when the DML is an insert/update or delete. 
    --
    nRows := DBMS_SQL.Execute(gCursor);
    --
    -- Output a column header
    --
    IF gIncludeHeader = 1 THEN
        
        vSeparator := '';
        cLine := EMPTY_CLOB();
        
        FOR i IN 1 .. Desc_Tab.Count LOOP
            
            cLine := cLine || vSeparator || '"' || REPLACE(Desc_Tab(i).Col_Name, '"', '""') || '"';
            
            vSeparator := ',';
            
        END LOOP;
        
        rHTTP_CHUNK.LengthBHex := TRIM(TO_CHAR(DBMS_LOB.GetLength(CLOB_TO_BLOB(cLine)), 'XXXX'));
        
        rHTTP_CHUNK.Text := DBMS_LOB.Substr(cLine, 4000, 1);
        
        PIPE ROW(rHTTP_CHUNK);
        
    END IF;
    --
    -- Output data
    --
    LOOP
        
        EXIT WHEN (DBMS_SQL.Fetch_Rows(gCursor) <= 0);
        
        vSeparator := '';
        
        cLine := EMPTY_CLOB();
        
        FOR i IN 1 .. nColumns LOOP
            
            IF Desc_Tab(i).Col_Type <> 112 THEN
                
                DBMS_SQL.Column_Value(gCursor, i, vColumnValue);
                
                cLine := cLine
                || vSeparator
                || CASE
                    WHEN Desc_Tab(i).Col_Type <> 2 THEN '"' || REPLACE(vColumnValue, '"', '""') || '"'
                    ELSE vColumnValue
                END;
                
            ELSE
                
                DBMS_SQL.Column_Value(gCursor, i, cColumnValue);
                
                cLine := cLine || vSeparator || '"' || REPLACE(cColumnValue, '"', '""') || '"';
                
            END IF;
            
            vSeparator := ',';
            
        END LOOP;
        
        cLine := cLine || CHR(10);
        
        nChunkStart := 1;
        
        LOOP
            
            vChunk := DBMS_LOB.Substr(cLine, 1000, nChunkStart);
            
            IF LENGTH(vChunk) = 0 OR vChunk IS NULL THEN
                
                EXIT;
                
            END IF;
            
            rHTTP_CHUNK.ID := rHTTP_CHUNK.ID + 1;
            
            rHTTP_CHUNK.LengthBHex := TRIM(TO_CHAR(LENGTHB(vChunk), 'XXXX'));
            
            rHTTP_CHUNK.Text := vChunk;
            
            PIPE ROW(rHTTP_CHUNK);
            
            IF (LENGTHB(vChunk) < 1000) THEN
                
                EXIT;
                
            END IF;
            
            nChunkStart := nChunkStart + 1000;
            
        END LOOP;
        
        nRows := nRows + 1;
        
    END LOOP;
    
    IF DBMS_LOB.GetLength(cColumnValue) > 0 THEN
        
        DBMS_LOB.FreeTemporary(cColumnValue);
        
    END IF;
    
    IF DBMS_LOB.GetLength(cLine) > 0 THEN
        
        DBMS_LOB.FreeTemporary(cLine);
        
    END IF;
    
    RETURN;
    --
    -- In the event of ANY error, re-raise the error.
    --
    EXCEPTION
    WHEN invalid_type THEN
        
        RETURN;
        
    WHEN OTHERS THEN
        
        IF DBMS_LOB.GetLength(cColumnValue) > 0 THEN
            
            DBMS_LOB.FreeTemporary(cColumnValue);
            
        END IF;
        
        IF DBMS_LOB.GetLength(cLine) > 0 THEN
            
            DBMS_LOB.FreeTemporary(cLine);
            
        END IF;
        
        RAISE;
        
        RETURN;
        
    END;
    
END;
/

SET ARRAYSIZE 1;
SHOW ERRORS;

/*
--test
SET SERVEROUTPUT ON;

SELECT ID,
LengthBHex,
LENGTHB(Text) AS LengthB$Text,
Text
FROM TABLE
(
    TABLE_TO_HTML_CHUNKS
    (
        TABLE_TO_QUERY('COUNTRY'),
        0
    )
);
ORDER BY LENGTHB(Text) DESC;

SELECT ID,
LengthBHex,
LENGTHB(Text) AS LengthB$Text,
Text
FROM TABLE
(
    TABLE_TO_HTML_CHUNKS
    (
        TABLE_TO_QUERY('GEONAMES', 'WHERE Country_ID = ''CYP'' AND CountrySubdiv_Code = ''02''')
    )
);

--test if the output is piped in a FOR loop and is guaranteed sequential
SET SERVEROUTPUT ON;

DECLARE
    
    nPreviousID PLS_INTEGER := 0;
    
BEGIN
    
    DBMS_OUTPUT.Enable(1000000);
    
    FOR C IN
    (
        SELECT ID,
        LengthBHex,
        Text
        FROM TABLE
        (
            TABLE_TO_HTML_CHUNKS
            (
                TABLE_TO_QUERY('LANGUAGE')
            )
        )
    ) LOOP
        
        DBMS_OUTPUT.Put_Line(TO_CHAR(SYSDATE, 'HH24:MI:SS') || ' : ' || TO_CHAR(C.ID));
        
        IF C.ID <= nPreviousID THEN
            
            DBMS_OUTPUT.Put_Line(TO_CHAR(C.ID) || '<=' || TO_CHAR(nPreviousID));
            
        END IF;
        
        nPreviousID := C.ID;
        
    END LOOP;
    
END;
/
--yup, it is!
*/