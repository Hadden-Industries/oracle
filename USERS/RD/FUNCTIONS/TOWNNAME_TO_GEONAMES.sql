CREATE OR REPLACE
FUNCTION TOWNNAME_TO_GEONAMES
(
    gTownName IN VARCHAR2,
    gCountry_ID IN CHAR DEFAULT NULL,
    gCountrySubdiv_Code IN VARCHAR2 DEFAULT NULL
)
RETURN INTEGER
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    nGeoNames_ID GEONAMES.ID%TYPE := NULL;
    
BEGIN
    
    SELECT GeoNames_ID
    INTO nGeoNames_ID
    FROM
    (
        SELECT D.Country_ID,
        CASE WHEN D.CountrySubdiv_Code IS NULL THEN COALESCE(F.GeoNames_ID, G.GeoNames_ID)
            ELSE E.GeoNames_ID
        END AS GeoNames_ID
        FROM
        (
            SELECT gCountry_ID AS Country_ID,
            (
                --Get the top-level country subdivision
                SELECT COALESCE(Parent$CountrySubdiv_Code, Code)
                FROM COUNTRYSUBDIV
                WHERE Country_ID = gCountry_ID
                AND Code = gCountrySubdiv_Code
            ) AS CountrySubdiv_Code,
            CASE
                WHEN gCountry_ID = 'FRA' AND INSTR(UPPER(gTownName), ' CEDEX') > 0 THEN TRIM
                (
                    SUBSTR
                    (
                        gTownName,
                        1,
                        INSTR
                        (
                            UPPER(gTownName),
                            ' CEDEX'
                        )
                        - 1
                    )
                )
                WHEN gCountry_ID = 'IRL' AND UPPER(gTownName) LIKE 'DUBLIN%' THEN 'DUBLIN'
                WHEN gCountry_ID = 'CZE' AND (UPPER(gTownName) LIKE 'PRAGUE%' OR UPPER(gTownName) LIKE 'PRAHA%') THEN 'PRAGUE'
                WHEN gCountry_ID = 'SVK' AND (UPPER(gTownName) LIKE 'BRATISLAVA%') THEN 'BRATISLAVA'
                ELSE gTownName
            END AS TownName
            FROM DUAL
        ) D
        LEFT OUTER JOIN UNIQUECOUNTRYSUBDIV$TOWNNAME E
            ON D.Country_ID = E.Country_ID
                    AND D.CountrySubdiv_Code = E.CountrySubdiv_Code
                    AND TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE
                                (
                                    CASE
                                        WHEN INSTR(D.TownName, '(') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, '(') - 1)
                                        WHEN INSTR(D.TownName, ',') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, ',') - 1)
                                        ELSE D.TownName
                                    END,
                                    '-',
                                    ' '
                                )
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ) = E.Name
        LEFT OUTER JOIN UNIQUECOUNTRY$TOWNNAME F
            ON D.Country_ID = F.Country_ID
                    AND TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE
                                (
                                    CASE
                                        WHEN INSTR(D.TownName, '(') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, '(') - 1)
                                        WHEN INSTR(D.TownName, ',') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, ',') - 1)
                                        ELSE D.TownName
                                    END,
                                    '-',
                                    ' '
                                )
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ) = F.Name
        LEFT OUTER JOIN UNIQUE$TOWNNAME G
            ON TRIM
                    (
                        REGEXP_REPLACE
                        (
                            UPPER
                            (
                                REPLACE
                                (
                                    CASE
                                        WHEN INSTR(D.TownName, '(') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, '(') - 1)
                                        WHEN INSTR(D.TownName, ',') > 0 THEN SUBSTR(D.TownName, 1, INSTR(D.TownName, ',') - 1)
                                        ELSE D.TownName
                                    END,
                                    '-',
                                    ' '
                                )
                            ),
                            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
                            ''
                        )
                    ) = G.Name
    );
    
    RETURN nGeoNames_ID;
    
EXCEPTION
WHEN NO_DATA_FOUND THEN
    
    RETURN NULL;
    
END;
/

/*
--test
--UK
SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>'GBR',
    gCountrySubdiv_Code=>'',
    gTownName=>'Newcastle-Upon-Tyne'
);

--Test giving a lowest-level subdivision
SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>'GBR',
    gCountrySubdiv_Code=>'HRY',
    gTownName=>'Wood Green'
);

--Deal with 'CEDEX'
SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>'FRA',
    gCountrySubdiv_Code=>'',
    gTownName=>'Boulogne-Billancourt cedex'
);

--Handling of the country subdivision
SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>'USA',
    gCountrySubdiv_Code=>'FL',
    gTownName=>'Springfield'
);

SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>'USA',
    gCountrySubdiv_Code=>'TX',
    gTownName=>'Springfield'
);

SELECT *
FROM GEONAMES
WHERE ID = TOWNNAME_TO_GEONAMES
(
    gCountry_ID=>NULL,
    gCountrySubdiv_Code=>NULL,
    gTownName=>'Cologne'
);
*/