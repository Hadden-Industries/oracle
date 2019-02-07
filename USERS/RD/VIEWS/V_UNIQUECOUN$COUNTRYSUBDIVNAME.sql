--DROP VIEW V_UNIQUECOUN$COUNTRYSUBDIVNAME;
CREATE OR REPLACE
VIEW V_UNIQUECOUN$COUNTRYSUBDIVNAME
AS
SELECT Country_ID,
CountrySubdiv_Code,
Name,
GeoNames_ID
FROM
(
    SELECT Country_ID,
    CountrySubdiv_Code,
    Name,
    GeoNames_ID,
    Priority,
    ROW_NUMBER() OVER (PARTITION BY Country_ID, Name ORDER BY Priority, CountrySubdiv_Code) AS RN
    FROM
    (
        SELECT Country_ID,
        CountrySubdiv_Code,
        TRIM
        (
            REGEXP_REPLACE
            (
                UPPER
                (
                    REPLACE
                    (
                        REGEXP_REPLACE(Name,'[[:blank:]]{2,}',' '),
                        '-',
                        ' '
                    )
                ),
                '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                ''
            )
        ) AS Name,
        GeoNames_ID,
        Priority
        FROM
        (
            SELECT B.GeoNames_ID,
            A.Country_ID,
            A.Code AS CountrySubdiv_Code,
            A.Code AS Name,
            CASE
                --favour first-order subdivisions
                WHEN A.Parent$CountrySubdiv_Code IS NULL THEN -8
                ELSE -7
            END AS Priority
            FROM COUNTRYSUBDIV A
            LEFT OUTER JOIN GEONAMESADMINCODE B
                ON A.Country_ID = B.Country_ID
                        AND A.Code = B.CountrySubdiv_Code
            --
            UNION ALL
            --
            SELECT C.GeoNames_ID,
            A.Country_ID,
            A.CountrySubdiv_Code,
            A.Name,
            CASE
                --favour first-order subdivisions
                WHEN B.Parent$CountrySubdiv_Code IS NULL THEN -6
                ELSE -5
            END AS Priority
            FROM COUNTRYSUBDIVNAME A
            INNER JOIN COUNTRYSUBDIV B
                ON A.Country_ID = B.Country_ID
                        AND A.CountrySubdiv_Code = B.Code
            LEFT OUTER JOIN GEONAMESADMINCODE C
                ON A.Country_ID = C.Country_ID
                        AND A.CountrySubdiv_Code = C.CountrySubdiv_Code
            --
            UNION ALL
            --
            SELECT B.Geonames_ID,
            A.Country_ID,
            A.Code AS CountrySubdiv_Code,
            A.Name,
            CASE
                --favour official English names
                WHEN A.IsNameOfficial ='T' THEN -4
                ELSE -3
            END
            - CASE
                --favour first-order subdivisions
                WHEN A.Parent$CountrySubdiv_Code IS NULL THEN -0.5
                ELSE 0
            END AS Priority
            FROM COUNTRYSUBDIV A
            LEFT OUTER JOIN GEONAMESADMINCODE B
                ON A.Country_ID = B.Country_ID
                        AND A.Code = B.CountrySubdiv_Code
            --
            UNION ALL
            --
            SELECT GeoNames_ID,
            Country_ID,
            CountrySubdiv_Code,
            Name,
            CASE
                --favour first-order subdivisions
                WHEN Parent$GeoNamesAdminCode_ID IS NULL THEN -2
                ELSE -1
            END AS Priority
            FROM GEONAMESADMINCODE
            WHERE Name IS NOT NULL
            AND CountrySubdiv_Code IS NOT NULL
            --
            UNION ALL
            --
            SELECT /*+ USE_NL(A B) */
            B.GeoNames_ID,
            B.Country_ID,
            B.CountrySubdiv_Code,
            A.Name,
            CASE
                --favour first-order subdivisions
                WHEN Parent$GeoNamesAdminCode_ID IS NULL THEN 0
                ELSE A.ID
            END AS Priority
            FROM GEONAMESALTNAME A
            INNER JOIN GEONAMESADMINCODE B
                ON A.GeoNames_ID = B.GeoNames_ID
            WHERE B.CountrySubdiv_Code IS NOT NULL
            AND (A.URL IS NULL OR A.URL = 'F')
        )
    )
    WHERE Name IS NOT NULL
)
WHERE RN = 1
WITH READ ONLY;

/*
--test
SELECT *
FROM V_UNIQUECOUN$COUNTRYSUBDIVNAME;
*/