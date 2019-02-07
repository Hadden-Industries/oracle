SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE MERGE_FXRATE_GAPS
(
    gDateFrom IN FXRATE.DateX%TYPE DEFAULT TO_DATE('1990-01-01', 'YYYY-MM-DD'),
    gDateTo IN FXRATE.DateX%TYPE DEFAULT TRUNC(SYSDATE),
    gRowsMerged IN OUT NOCOPY INTEGER
)
AS
    
    --Program variable
    nRowsMerged INTEGER := 0;
    
    --Error variable
    vError VARCHAR2(255 BYTE) := '';
    
BEGIN
    
    DBMS_OUTPUT.Enable(NULL);
    
    DBMS_APPLICATION_INFO.Set_Module('MERGE_FXRATE_GAPS', 'Inserting');
    
    FOR C IN
    (
        SELECT (DateFrom + LEVEL - 1) AS DateX
        FROM
        (
            SELECT gDateFrom AS DateFrom,
            gDateTo AS DateTo
            FROM DUAL
        )
        CONNECT BY LEVEL <= (DateTo - DateFrom + 1)
    ) LOOP
        
        MERGE_FXRATE_NEXT_DAY(C.DateX);
        
        nRowsMerged := nRowsMerged + SQL%ROWCOUNT;
        
        DBMS_APPLICATION_INFO.Set_Action(TO_CHAR(C.DateX, 'YYYY-MM-DD') || ',' || TO_CHAR(nRowsMerged));
        
    END LOOP;
    
    gRowsMerged := nRowsMerged;
    
    DBMS_APPLICATION_INFO.Set_Module(NULL, NULL);
    
EXCEPTION
WHEN OTHERS THEN
    
    vError := SUBSTRB(SQLErrM, 1, 255);
    
    DBMS_OUTPUT.Put_Line(vError);
    
    DBMS_APPLICATION_INFO.Set_Module(NULL, NULL);
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

DECLARE
    
    nRowsMerged INTEGER := 0;
    
BEGIN
    
    DBMS_OUTPUT.Enable;
    
    MERGE_FXRATE_GAPS
    (
        TO_DATE('1990-01-01', 'YYYY-MM-DD'),
        TRUNC(SYSDATE),
        nRowsMerged
    );
    
    DBMS_OUTPUT.Put_Line(TO_CHAR(nRowsMerged));
    
    COMMIT;
    
END;
/
*/