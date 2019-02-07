CREATE OR REPLACE
VIEW V_UNIQUE$TOWNNAME
AS
SELECT CAST(Name AS VARCHAR2(200 CHAR)) AS Name,
CAST(GeoNames_ID AS INTEGER) AS GeoNames_ID
FROM
(
    SELECT Name,
    GeoNames_ID,
    ROW_NUMBER() OVER
    (
        PARTITION BY Name
        ORDER BY Priority DESC,
        Population DESC NULLS LAST,
        CASE GeoNamesFeatureCode_ID
            WHEN 'PPLC' THEN 0
            WHEN 'PPLG' THEN 1
            WHEN 'PPLA' THEN 2
            WHEN 'PPLA2' THEN 3
            WHEN 'PPLA3' THEN 4
            WHEN 'PPLA4' THEN 5
            WHEN 'PPL' THEN 6
            WHEN 'PPLS' THEN 7
            WHEN 'PPLX' THEN 8
            WHEN 'PPLL' THEN 9
            WHEN 'PPLF' THEN 10
            WHEN 'PPLR' THEN 11
            WHEN 'STLMT' THEN 12
            WHEN 'PPLQ' THEN 13
            WHEN 'PPLW' THEN 14
            WHEN 'PPLCH' THEN 15
            WHEN 'PPLH' THEN 16
            ELSE 17
        END,
        DateModified,
        RowID
    ) AS RN
    FROM S_TOWNNAME
)
WHERE RN = 1
WITH READ ONLY;