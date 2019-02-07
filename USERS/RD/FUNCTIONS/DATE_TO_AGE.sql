--YYYY-MM-DD"T"HH24:MI:SS & 'N' for Number
CREATE OR REPLACE
FUNCTION DATE_TO_AGE
(
    gDate IN DATE,
    gFormatMask IN VARCHAR2 DEFAULT NULL
)
RETURN VARCHAR2
PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    nDays SIMPLE_INTEGER := -1;
    nMonths SIMPLE_INTEGER := -1;
    nYears SIMPLE_INTEGER := -1;
    vReturn VARCHAR2(100 BYTE) := NULL;
    
BEGIN
    
    IF gFormatMask = 'N' THEN
        
        RETURN TO_CHAR
        (
            (SYSDATE_UTC - gDate) / 365.2425
        );
        
    END IF;
    
    IF INSTRB(gFormatMask, 'DD') > 0 THEN
        
        nDays:= TRUNC
        (
            SYSDATE_UTC - ADD_MONTHS
            (
                gDate,
                TRUNC
                (
                    MONTHS_BETWEEN(SYSDATE_UTC, gDate)/12
                ) * 12
                + TRUNC
                (
                    MOD
                    (
                        MONTHS_BETWEEN(SYSDATE_UTC, gDate),
                        12
                    )
                )
            )
        );
        
        vReturn := CASE
            WHEN nDays > 0 THEN TO_CHAR(nDays)
            || ' Day'
            || CASE
                WHEN nDays > 1 THEN 's'
                ELSE NULL
            END
            ELSE NULL
        END;
        
    END IF;
    
    IF INSTRB(gFormatMask, 'MM') > 0 OR nDays >= 0 THEN
        
        nMonths := TRUNC
        (
            MOD
            (
                MONTHS_BETWEEN(SYSDATE_UTC, gDate),
                12
            )
        );
        
        vReturn := CASE
            WHEN nMonths > 0 THEN TO_CHAR(nMonths)
            || ' Month'
            || CASE
                WHEN nMonths > 1 THEN 's'
                ELSE NULL
            END
            || CASE
                WHEN vReturn IS NOT NULL THEN ' '
                ELSE NULL
            END
            ELSE NULL
        END
        || vReturn;
        
    END IF;
    
    nYears := TRUNC
    (
        (MONTHS_BETWEEN(SYSDATE_UTC, gDate)/12)
    );
    
    vReturn := TO_CHAR(nYears)
    || CASE
    WHEN gFormatMask IS NOT NULL THEN ' Year'
        || CASE
            WHEN nYears > 1 THEN 's'
            ELSE NULL
        END
        || CASE
            WHEN vReturn IS NOT NULL THEN ' '
            ELSE NULL
        END
        || vReturn
        ELSE NULL
    END;
    
    RETURN vReturn;
    
EXCEPTION
WHEN OTHERS THEN
    
    RETURN NULL;
    
END;
/

/*
--test
SELECT DateTimeBirth,
CASE
    WHEN EXTRACT(YEAR FROM DateTimeBirth) = 1604 THEN NULL
    ELSE DATE_TO_AGE(DateTimeBirth, 'DD')
END AS Age_Full,
TO_NUMBER
(
    CASE
        WHEN EXTRACT(YEAR FROM DateTimeBirth) = 1604 THEN NULL
        ELSE DATE_TO_AGE(DateTimeBirth, 'N')
    END
) AS Age_Number,
CASE
    WHEN EXTRACT(YEAR FROM DateTimeBirth) = 1604 THEN NULL
    ELSE DATE_TO_AGE(DateTimeBirth)
END AS Age
FROM CERTIFICATEBIRTH
WHERE DateTimeBirth IS NOT NULL
AND Person_ID NOT IN
(
    SELECT Person_ID
    FROM CERTIFICATEDEATH
    WHERE DateTimeDeath IS NOT NULL
)
ORDER BY DateTimeBirth DESC;
*/