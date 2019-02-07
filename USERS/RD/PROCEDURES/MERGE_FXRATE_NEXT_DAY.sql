SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE MERGE_FXRATE_NEXT_DAY(gDate IN FXRATE.DateX%TYPE)
AS

BEGIN
    
    MERGE
    INTO FXRATE X
    USING
    (
        SELECT /*+ USE_NL(A B) */
        A.From$Currency_ID,
        A.To$Currency_ID,
        A.FXRateType_ID,
        A.DateTimeBasis,
        (A.DateTimeX + 1) AS DateTimeX,
        A.Rate
        FROM FXRATE A
        INNER JOIN CURRENCY B
            ON A.To$Currency_ID = B.ID
                    AND
                    (
                        B.DateStart IS NULL
                        OR
                        B.DateStart <= (A.DateTimeX + 1)
                    )
                    AND
                    (
                        B.DateEnd IS NULL
                        OR
                        B.DateEnd >= A.DateTimeX + 1
                    )
        WHERE A.DateX = TRUNC(gDate)
        --Day after this is the switch-over date of base currency (SELECT MAX(DateX) FROM FXRATE WHERE From$Currency_ID = 'USD')
        AND A.DateX <> TO_DATE('1999-01-03', 'YYYY-MM-DD')
    ) Y
        ON (X.From$Currency_ID = Y.From$Currency_ID
                AND X.To$Currency_ID = Y.To$Currency_ID
                AND X.DateX = TRUNC(Y.DateTimeX)
                AND X.FXRateType_ID = Y.FXRateType_ID)
    WHEN MATCHED THEN UPDATE SET X.DateTimeBasis = Y.DateTimeBasis,
    X.DateTimeX = Y.DateTimeX,
    X.Rate = Y.Rate
    --Where this is already an extrapolated value
    WHERE X.DateTimeX <> X.DateTimeBasis
    AND
    (
        X.DateTimeX <> Y.DateTimeX
        OR X.Rate <> Y.Rate
    )
    WHEN NOT MATCHED THEN INSERT
    (
        FROM$CURRENCY_ID,
        TO$CURRENCY_ID,
        FXRATETYPE_ID,
        DATETIMEBASIS,
        DATETIMEX,
        RATE
    )
    VALUES
    (
        Y.From$Currency_ID,
        Y.To$Currency_ID,
        Y.FXRateType_ID,
        Y.DateTimeBasis,
        Y.DateTimeX,
        Y.Rate
    );
    
END;
/

/*
--test
SET SERVEROUTPUT ON;
SET TIMING ON;

BEGIN
    
    MERGE_FXRATE_NEXT_DAY(TRUNC(SYSDATE-1));
    
    DBMS_OUTPUT.Put_Line(TO_CHAR(SQL%ROWCOUNT));
    
END;
/
*/