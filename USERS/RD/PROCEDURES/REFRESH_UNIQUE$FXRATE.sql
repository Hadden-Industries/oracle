SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE REFRESH_UNIQUE$FXRATE
AS

BEGIN
    
    MERGE
    INTO UNIQUE$FXRATE X
    USING
    (
        SELECT From$Currency_ID,
        To$Currency_ID,
        DateX,
        Rate
        FROM
        (
            SELECT From$Currency_ID,
            To$Currency_ID,
            DateX,
            Rate,
            ROW_NUMBER() OVER (PARTITION BY From$Currency_ID, To$Currency_ID, DateX ORDER BY Priority) AS RN
            FROM
            (
                SELECT A.From$Currency_ID,
                A.To$Currency_ID,
                A.DateX,
                AVG(Rate) AS Rate,
                0 AS Priority
                FROM FXRATE A
                INNER JOIN FXRATETYPE B
                    ON A.FXRateType_ID = B.ID
                WHERE B.Name IN ('Ask', 'Bid')
                GROUP BY A.From$Currency_ID,
                A.To$Currency_ID,
                A.DateX
                --
                UNION ALL
                --
                SELECT A.From$Currency_ID,
                A.To$Currency_ID,
                A.DateX,
                Rate,
                1 AS Priority
                FROM FXRATE A
                INNER JOIN FXRATETYPE B
                    ON A.FXRateType_ID = B.ID
                WHERE B.Name = 'Mid'
            )
        )
        WHERE RN = 1
        --
        MINUS
        --
        SELECT From$Currency_ID,
        To$Currency_ID,
        DateX,
        Rate
        FROM UNIQUE$FXRATE
    ) Y
    ON (X.From$Currency_ID = Y.From$Currency_ID
            AND X.To$Currency_ID = Y.To$Currency_ID
            AND X.DateX = Y.DateX)
    WHEN MATCHED THEN UPDATE SET X.Rate = Y.Rate
    WHEN NOT MATCHED THEN INSERT
    (
        FROM$CURRENCY_ID,
        TO$CURRENCY_ID,
        DATEX,
        RATE
    )
    VALUES
    (
        Y.From$Currency_ID,
        Y.To$Currency_ID,
        Y.DateX,
        Y.Rate
    );
    
    TOUCH('UNIQUE$FXRATE');
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    REFRESH_UNIQUE$FXRATE;
    
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SQL%ROWCOUNT));
    
    COMMIT;
    
END;
/
*/