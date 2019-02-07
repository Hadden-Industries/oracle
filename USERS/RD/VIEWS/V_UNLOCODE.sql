SET SERVEROUTPUT ON;

CREATE OR REPLACE
VIEW V_UNLOCODE
AS
SELECT C.Country_ID,
C.Location AS Code,
C.Country_Alpha2,
E.Code AS CountrySubdiv_Code,
C.Country_Alpha2 || ' ' || C.Location AS ID,
C.Status AS UNLOCODEStatus_ID,
C.NameWODiacritics AS Name,
C.Name AS NameOfficial,
C.DateX AS DateReference,
CASE
    WHEN C.CoOrdinates IS NOT NULL THEN TO_NUMBER
    (
        CASE SUBSTR(C.CoOrdinates, 5, 1)
            WHEN 'S' THEN '-'
            WHEN 'N' THEN '+'
            ELSE NULL
        END
        || SUBSTR(C.CoOrdinates, 1, 2)
    )
    + ROUND(TO_NUMBER(SUBSTR(C.CoOrdinates, 3, 2))/60, 2)
    ELSE NULL
END AS Latitude,
CASE
    WHEN C.CoOrdinates IS NOT NULL AND TO_NUMBER(SUBSTR(C.CoOrdinates, 7, 3)) BETWEEN -179.99 AND 179.99 THEN TO_NUMBER
    (
        CASE SUBSTR(C.CoOrdinates, 12, 1)
            WHEN 'W' THEN '-'
            WHEN 'E' THEN '+'
            ELSE NULL
        END
        || SUBSTR(C.CoOrdinates, 7, 3)
    )
    + ROUND(TO_NUMBER(SUBSTR(C.CoOrdinates, 10, 2))/60, 2)
    WHEN C.CoOrdinates IS NOT NULL AND TO_NUMBER(SUBSTR(C.CoOrdinates, 7, 3)) NOT BETWEEN -179.99 AND 179.99 THEN TO_NUMBER
    (
        CASE SUBSTR(C.CoOrdinates, 12, 1)
            WHEN 'W' THEN '-'
            WHEN 'E' THEN '+'
            ELSE NULL
        END
        || SUBSTR(C.CoOrdinates, 7, 2)
    )
    + ROUND(ROUND(TO_NUMBER(SUBSTR(C.CoOrdinates, 9, 3)), -1)/60, 2)
    ELSE NULL
END AS Longitude,
C.IATA AS IATA_ID,
CASE
    WHEN C.CoOrdinates IS NOT NULL AND TO_NUMBER(SUBSTR(C.CoOrdinates, 7, 3)) NOT BETWEEN -179.99 AND 179.99 THEN CASE
        WHEN C.Remarks IS NOT NULL THEN C.Remarks || '
        Incorrect longitude format in source'
        ELSE 'Incorrect longitude format in source'
    END
    ELSE C.Remarks 
END AS Comments
FROM
(
    SELECT A.*,
    B.ID AS Country_ID,
    B.Alpha2 AS Country_Alpha2
    FROM
    (
        SELECT Country,
        Location,
        Name,
        NameWODiacritics,
        CASE
            --United Kingdom
            WHEN Country = 'GB' AND Location IN ('DSE', 'FLI') AND Subdivision = 'CWD' THEN 'FLN'
            WHEN Country = 'GB' AND Location IN ('LSD') AND Subdivision = 'WYK' THEN 'BRD'
            --Indonesia's Papua https://www.iso.org/obp/ui/#iso:code:3166:ID
            WHEN Country= 'ID' AND Subdivision = 'IJ' THEN 'PP'
            --http://en.wikipedia.org/wiki/Provinces_of_Kenya
            WHEN Country = 'KE' AND Location IN ('LIM') AND Subdivision = '200' THEN '13'
            WHEN Country = 'KE' AND Location IN ('ARI') AND Subdivision = '400' THEN '22'
            WHEN Country = 'KE' AND Location IN ('MWI') AND Subdivision = '400' THEN '18'
            WHEN Country = 'KE' AND Location IN ('DDB') AND Subdivision = '500' THEN '07'
            WHEN Country = 'KE' AND Location IN ('MUH') AND Subdivision = '600' THEN '17'
            WHEN Country = 'KE' AND Location IN ('SIA') AND Subdivision = '600' THEN '38'
            WHEN Country = 'KE' AND Location IN ('RNA') AND Subdivision = '700' THEN '31'
            --Others
            WHEN Country = 'LV' AND Location IN ('VIL') AND Subdivision = 'BL' THEN '108'
            WHEN Country = 'LV' AND Location IN ('PAC') AND Subdivision = 'BU' THEN '016'
            WHEN Country = 'LV' AND Location IN ('DGP') AND Subdivision = 'DW' THEN 'DGV'
            WHEN Country = 'LV' AND Location IN ('AKI') AND Subdivision = 'JK' THEN '004'
            WHEN Country = 'LV' AND Location IN ('CEN') AND Subdivision = 'JL' THEN '041'
            WHEN Country = 'LV' AND Location IN ('PRE') AND Subdivision = 'PR' THEN '073'
            WHEN Country = 'LV' AND Location IN ('BMT') AND Subdivision = 'RI' THEN 'RIX'
            WHEN Country = 'PL' AND Location IN ('SWA') AND Subdivision = 'PO' THEN 'WP'
            WHEN Country = 'VN' AND Location IN ('HTY') AND Subdivision = '15' THEN 'HN'
            ELSE Subdivision
        END AS Subdivision,
        Status,
        DateX,
        IATA,
        CoOrdinates,
        CASE Remarks
            WHEN CHR(13) THEN NULL
            ELSE Remarks
        END AS Remarks
        FROM
        (
            --Some locations have multiple names, choose only one per country/location pair
            SELECT ROW_NUMBER() OVER
            (
                PARTITION BY A.Country, A.Location
                ORDER BY LENGTHB
                (
                    REGEXP_REPLACE(A.Function, '[^012345678B]', '')
                ) DESC,
                A.DateX DESC,
                A.CoOrdinates NULLS LAST,
                RowID
            ) AS RN,
            A.*
            FROM S_UNLOCODE A
            WHERE
            (
                A.Change <> 'X'
                OR A.Change IS NULL
            )
        )
        WHERE RN = 1
    ) A
    INNER JOIN COUNTRY AS OF PERIOD FOR VALID_TIME SYSDATE B
        ON A.Country = B.Alpha2
    WHERE A.Location IS NOT NULL
) C
INNER JOIN UNLOCODESTATUS D
    ON C.Status = D.ID
LEFT OUTER JOIN COUNTRYSUBDIV E
    ON C.Country_ID = E.Country_ID
            AND C.Subdivision = E.Code
WITH READ ONLY;

/*
--test
SELECT *
FROM V_UNLOCODE;
*/