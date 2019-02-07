CREATE OR REPLACE
VIEW COUNTRYSUBDIV#GBRONSGEOGCODE
AS
WITH STAGING_GBRONSGEOGCODE AS
(
    SELECT B.ID AS GBRONSGeogCode_ID,
    B.Name AS GBRONSGeogCode_Name
    FROM GBRONSRGC A
    INNER JOIN GBRONSGEOGCODE B
        ON A.ID = B.GBRONSRGC_ID
    WHERE A.Status = 'Current'
    AND A.Name IN
    (
        'Council Areas',
        'Counties',
        'London Boroughs',
        'Metropolitan Districts',
        'Unitary Authorities',
        --NIR
        'Local Government Districts'
    )
),
--
GBRONSGEOGCODE_NULLPARENT AS
(
    SELECT B.ID AS GBRONSGeogCode_ID,
    B.Name AS GBRONSGeogCode_Name
    FROM GBRONSRGC A
    INNER JOIN GBRONSGEOGCODE B
        ON A.ID = B.GBRONSRGC_ID
    WHERE A.Status = 'Current'
    AND A.Name IN
    (
        'Country',
        'United Kingdom',
        'Great Britain',
        'England and Wales'
    )
)
--
SELECT A.Country_ID,
A.Code AS CountrySubdiv_Code,
B.GBRONSGeogCode_ID
FROM COUNTRYSUBDIV AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) A
LEFT OUTER JOIN STAGING_GBRONSGEOGCODE B
    ON REPLACE
            (
                CASE
                    WHEN A.Name = 'Vale of Glamorgan, The' THEN 'Vale of Glamorgan'
                    WHEN A.Name = 'Durham County' THEN 'County Durham'
                    WHEN A.Name = 'Edinburgh, City of' THEN 'City of Edinburgh'
                    WHEN A.Name = 'Herefordshire' THEN 'Herefordshire, County of'
                    WHEN A.Name = 'Kingston upon Hull' THEN 'Kingston upon Hull, City of'
                    WHEN A.Name = 'London, City of' THEN 'City of London'
                    WHEN A.Name = 'Rhondda, Cynon, Taff' THEN 'Rhondda Cynon Taf'
                    WHEN A.Name = 'Scottish Borders, The' THEN 'Scottish Borders'
                    WHEN A.Name = 'Eilean Siar' THEN 'Na h-Eileanan Siar'
                    WHEN A.Name = 'Armagh, Banbridge and Craigavon' THEN 'Armagh City, Banbridge and Craigavon'
                    WHEN A.Name = 'Derry and Strabane' THEN 'Derry City and Strabane'
                    ELSE A.Name
                END,
                '&',
                'and'
            )
            = REPLACE
            (
                B.GBRONSGeogCode_Name,
                '&',
                'and'
            )
WHERE A.Country_ID = 'GBR'
AND A.Parent$CountrySubdiv_Code IS NOT NULL
--
UNION ALL
--
SELECT A.Country_ID,
A.Code AS CountrySubdiv_Code,
B.GBRONSGeogCode_ID
FROM COUNTRYSUBDIV AS OF PERIOD FOR VALID_TIME CAST(SYS_EXTRACT_UTC(SYSTIMESTAMP) AS DATE) A
LEFT OUTER JOIN GBRONSGEOGCODE_NULLPARENT B
    ON A.Name = B.GBRONSGeogCode_Name
WHERE A.Country_ID = 'GBR'
AND A.Parent$CountrySubdiv_Code IS NULL
WITH READ ONLY;

/*
--Help in finding matches
SELECT *
FROM CHD A
INNER JOIN GBRONSRGC B
    ON A.GBRONSRGC_ID = B.ID
WHERE A.Name LIKE '%Armagh, Banbridge and Craigavon%';

--Non-matches
SELECT *
FROM COUNTRYSUBDIV#GBRONSGEOGCODE
WHERE GBRONSGeogCode_ID IS NULL;

--Duplicates?
SELECT Country_ID,
CountrySubdiv_Code
FROM COUNTRYSUBDIV#GBRONSGEOGCODE
GROUP BY Country_ID,
CountrySubdiv_Code
HAVING COUNT(*) > 1;
--0

SELECT GBRONSGeogCode_ID
FROM COUNTRYSUBDIV#GBRONSGEOGCODE
GROUP BY GBRONSGeogCode_ID
HAVING COUNT(*) > 1;
--0

SELECT *
FROM COUNTRYSUBDIV#GBRONSGEOGCODE A
INNER JOIN COUNTRYSUBDIV B
    ON A.Country_ID = B.Country_ID
            AND A.CountrySubdiv_Code = B.Code
LEFT OUTER JOIN GBRONSGEOGCODE C
    ON A.GBRONSGeogCode_ID = C.ID
--not first-level
WHERE B.Parent$CountrySubdiv_Code IS NOT NULL
AND C.Geometry IS NULL;
--0

--test
SELECT *
FROM COUNTRYSUBDIV#GBRONSGEOGCODE
ORDER BY GBRONSGeogCode_ID NULLS FIRST,
Country_ID,
CountrySubdiv_Code;
*/