CREATE OR REPLACE
VIEW V_UNIQUE$COUNTRYNAME
AS
SELECT CAST(Name AS VARCHAR2(200 CHAR)) AS Name,
CAST(Country_ID AS CHAR(3 BYTE)) AS Country_ID,
CAST(GeoNames_ID AS INTEGER) AS GeoNames_ID
FROM
(
    SELECT X.Name,
    X.Country_ID,
    X.GeoNames_ID,
    ROW_NUMBER() OVER
    (
        PARTITION BY X.Name
        ORDER BY X.Priority DESC,
        COALESCE(Y.DateEnd, TO_DATE('9999-12-31', 'YYYY-MM-DD')) DESC
    ) AS RN
    FROM
    (
        SELECT TRIM
        (
            REGEXP_REPLACE
            (
                REGEXP_REPLACE
                (
                    UPPER(Name),
                    '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                    ''
                ),
                '[[:blank:]]{2,}',
                ' '
            )
        ) AS Name,
        Country_ID,
        GeoNames_ID,
        Priority
        FROM
        (
            SELECT Name,
            ID AS Country_ID,
            NULL AS GeoNames_ID,
            12 AS Priority
            FROM ALTNAME
            WHERE TableLookup_Name = 'COUNTRY'
            --
            UNION ALL
            --
            SELECT A.ID AS Name,
            A.ID AS Country_ID,
            NULL AS GeoNames_ID,
            11 AS Priority
            FROM COUNTRY A
            WHERE A.Name IS NOT NULL
            --
            UNION ALL
            --
            SELECT A.Alpha2 AS Name,
            A.ID AS Country_ID,
            NULL AS GeoNames_ID,
            10 AS Priority
            FROM COUNTRY A
            WHERE A.Name IS NOT NULL
            --
            UNION ALL
            --
            SELECT A.Name,
            A.ID AS Country_ID,
            NULL AS GeoNames_ID,
            9 AS Priority
            FROM COUNTRY A
            WHERE A.Name IS NOT NULL
            --
            UNION ALL
            --
            SELECT A.NameWithoutArticle AS Name,
            A.ID AS Country_ID,
            NULL AS GeoNames_ID,
            8 AS Priority
            FROM COUNTRY A
            WHERE A.NameWithoutArticle IS NOT NULL
            --
            UNION ALL
            --
            SELECT A.NameFull AS Name,
            A.ID AS Country_ID,
            NULL AS GeoNames_ID,
            7 AS Priority
            FROM COUNTRY A
            WHERE A.NameFull IS NOT NULL
            --
            UNION ALL
            --
            SELECT C.NameOfficial AS Name,
            C.Country_ID,
            C.ID AS GeoNames_ID,
            CASE B.Name
                WHEN 'historical political entity' THEN 4
                WHEN 'section of independent political entity' THEN 5
                ELSE 6
            END AS Priority
            FROM GEONAMESFEATURECLASS A
            INNER JOIN GEONAMESFEATURECODE B
                ON A.ID = B.GeoNamesFeatureClass_ID
            INNER JOIN GEONAMES C
                ON B.ID = C.GeoNamesFeatureCode_ID
            WHERE A.Name LIKE 'Country%'
            AND (B.ID LIKE 'PCL%' OR B.ID = 'TERR')
            AND C.NameOfficial IS NOT NULL
            --
            UNION ALL
            --
            SELECT C.Name,
            C.Country_ID,
            C.ID AS GeoNames_ID,
            CASE B.Name
                WHEN 'historical political entity' THEN 1
                WHEN 'section of independent political entity' THEN 2
                ELSE 3
            END AS Priority
            FROM GEONAMESFEATURECLASS A
            INNER JOIN GEONAMESFEATURECODE B
                ON A.ID = B.GeoNamesFeatureClass_ID
            INNER JOIN GEONAMES C
                ON B.ID = C.GeoNamesFeatureCode_ID
            WHERE A.Name LIKE 'Country%'
            AND (B.ID LIKE 'PCL%' OR B.ID = 'TERR')
            AND C.Name IS NOT NULL
            --
            UNION ALL
            --
            SELECT /*+ INDEX(D GEONAMESALTNAME_PK) */
            D.Name,
            C.Country_ID,
            C.ID AS GeoNames_ID,
            CASE B.Name
                WHEN 'historical political entity' THEN -2
                WHEN 'section of independent political entity' THEN -1
                ELSE 0
            END AS Priority
            FROM GEONAMESFEATURECLASS A
            INNER JOIN GEONAMESFEATURECODE B
                ON A.ID = B.GeoNamesFeatureClass_ID
            INNER JOIN GEONAMES C
                ON B.ID = C.GeoNamesFeatureCode_ID
            INNER JOIN GEONAMESALTNAME D
                ON C.ID = D.GeoNames_ID
            WHERE A.Name LIKE 'Country%'
            AND (B.ID LIKE 'PCL%' OR B.ID = 'TERR')
            AND (D.URL IS NULL OR D.URL = 'F')
        )
    ) X
    INNER JOIN COUNTRY Y
        ON X.Country_ID = Y.ID
    WHERE X.Name IS NOT NULL
)
WHERE RN = 1;

/*
--test
SELECT *
FROM V_UNIQUE$COUNTRYNAME
WHERE Name = 'CYPRUS';
*/