CREATE OR REPLACE
TRIGGER ADDRESS_BI_TRI
BEFORE INSERT
ON ADDRESS
FOR EACH ROW

DECLARE
    
    nAddedCSDFromPostcode SIMPLE_INTEGER := 0;
    
BEGIN
    
    IF :NEW.UUID IS NULL THEN
        
        :NEW.UUID := UNCANONICALISE_UUID(UUID_VER4);
        
    END IF;
    
    --Postcode invalid characters replaced
    :NEW.Postcode := CASE
        --Cyprus: Technically mail inbound from outside cyprus should have the postcode in CY-[postcode] format, but keep in canonical form here
        WHEN :NEW.Country_ID = 'CYP' THEN SUBSTRB
        (
            REGEXP_REPLACE
            (
                :NEW.Postcode,
                '[^0123456789]',
                ''
            ),
            1,
            4
        )
        --France
        WHEN :NEW.Country_ID = 'FRA' THEN SUBSTRB
        (
            REGEXP_REPLACE
            (
                :NEW.Postcode,
                '[^0123456789]',
                ''
            ),
            1,
            5
        )
        --Greece: Five digits, first three are major subdivision
        WHEN :NEW.Country_ID = 'GRC' THEN REGEXP_REPLACE
        (
            SUBSTRB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                ),
                1,
                5
            ),
            '^([[:digit:]]{3})([[:digit:]]{2})$',
            '\1 \2'
        )
        --Russian Federation
        WHEN
        (
            :NEW.Country_ID = 'RUS'
            AND LENGTHB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                )
            )
            = 6
        )
        THEN REGEXP_REPLACE
        (
            :NEW.Postcode,
            '[^0123456789]',
            ''
        )
        WHEN
        (
            :NEW.Country_ID = 'RUS'
            AND LENGTHB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                )
            )
            --Should always be six digits long
            <> 6
        )
        THEN NULL
        --United States
        WHEN
        (
            :NEW.Country_ID = 'USA'
            AND LENGTHB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                )
            )
            = 5
        )
        THEN REGEXP_REPLACE
        (
            :NEW.Postcode,
            '[^0123456789]',
            ''
        )
        WHEN
        (
            :NEW.Country_ID = 'USA'
            AND LENGTHB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                )
            )
            = 9
        )
        THEN REGEXP_REPLACE
        (
            REGEXP_REPLACE
            (
                :NEW.Postcode,
                '[^0123456789]',
                ''
            ),
            '^([[:digit:]]{5})([[:digit:]]{4})$',
            '\1-\2'
        )
        WHEN
        (
            :NEW.Country_ID = 'USA'
            AND LENGTHB
            (
                REGEXP_REPLACE
                (
                    :NEW.Postcode,
                    '[^0123456789]',
                    ''
                )
            )
            --Clearly incorrect postcode, so ignore
            NOT IN (5, 9)
        )
        THEN NULL
        --UK and dependent territories
        WHEN :NEW.Country_ID IN ('GBR', 'GGY', 'IMN', 'JEY') THEN REGEXP_REPLACE
        (
            CASE
                --When the third-last character is O, it is confused with 0
                WHEN SUBSTRB
                (
                    REGEXP_REPLACE(:NEW.Postcode, '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]', ''),
                    -3,
                    1
                )
                --So replace the first 'O' in the inbound with 0
                = 'O' THEN REGEXP_REPLACE
                (
                    REGEXP_REPLACE(:NEW.Postcode, '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]', ''),
                    'O',
                    '0',
                    LENGTHB
                    (
                        REGEXP_REPLACE(:NEW.Postcode, '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]', '')
                    )
                    - 2,
                    1
                )
                ELSE :NEW.Postcode
            END,
            '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]',
            ''
        )
        --Sanitise the postcode generally
        ELSE TRIM
        (
            --Remove leading and trailing spaces
            BOTH CHR(32)
            FROM REGEXP_REPLACE
            (
                UPPER
                (
                    --Replace all non-ASCII forms of the hyphen
                    REPLACE
                    (
                        REPLACE
                        (
                            REPLACE
                            (
                                :NEW.Postcode,
                                '–',
                                '-'
                            ),
                            '',
                            '-'
                        ),
                        '‐',
                        '-'
                    )
                ),
                '[^ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -]',
                ''
            )
        )
    END;
    
    :NEW.TownName := CASE
        --Singapore is a city-state, so fill in the town name when it is blank
        WHEN :NEW.Country_ID = 'SGP'
        AND TRIM
        (
            SINGLE_LINE(:NEW.TownName)
        )
        IS NULL THEN 'Singapore'
        ELSE TRIM
        (
            SINGLE_LINE(:NEW.TownName)
        )
    END;
    
    :NEW.Comments := TRIM
    (
        REMOVE_NON_XML_CHARS(:NEW.Comments)
    );
    
    IF :NEW.Country_ID IN ('GBR', 'GGY', 'IMN', 'JEY') AND :NEW.Postcode IS NOT NULL THEN
        
        --Fix UK (and dependent territories) postcodes to be in e-GIF format and append the lowest-level country subdivision
        BEGIN
            
            SELECT PostcodeeGIF,
            COALESCE(Second$CountrySubdiv_Code, CountrySubdiv_Code),
            CASE
                --UK postcode lookup does not split out into the second order country subdivision for Northern Ireland
                WHEN CountrySubdiv_Code = 'NIR' AND Second$CountrySubdiv_Code IS NULL THEN 0
                WHEN COALESCE(Second$CountrySubdiv_Code, CountrySubdiv_Code) IS NOT NULL THEN 1
                ELSE 0
            END
            INTO :NEW.Postcode,
            :NEW.CountrySubdiv_Code,
            nAddedCSDFromPostcode
            FROM GBRPOSTCODE
            WHERE Country_ID = :NEW.Country_ID
            AND Postcode = REPLACE(:NEW.Postcode, CHR(32));
            
            SELECT ID,
            Name
            INTO :NEW.GeoNames_ID,
            :NEW.TownName
            FROM GEONAMES
            WHERE ID = POSTCODE_TO_GEONAMES(:NEW.Postcode, :NEW.Country_ID);
            
        EXCEPTION
        --If the postcode could not be found, then it is invalid
        WHEN NO_DATA_FOUND THEN
            
            :NEW.Postcode := NULL;
            
        END;
        
    END IF;
    
    
    IF :NEW.GeoNames_ID IS NULL THEN
        
        :NEW.GeoNames_ID := TOWNNAME_TO_GEONAMES
        (
            :NEW.TownName,
            CASE
                WHEN :NEW.Country_ID = 'ZZZ' THEN NULL
                ELSE :NEW.Country_ID
            END,
            :NEW.CountrySubdiv_Code
        );
        
    END IF;
    
    
    --Only if you have not appended a country subdivision from postcode do you append from GeoNames
        IF (nAddedCSDFromPostcode = 0 AND :NEW.GeoNames_ID IS NOT NULL) THEN
            
            SELECT CASE
                WHEN :NEW.Country_ID = 'ZZZ' THEN Country_ID
                ELSE :NEW.Country_ID
            END,
            COALESCE(Second$CountrySubdiv_Code, CountrySubdiv_Code)
            INTO :NEW.Country_ID,
            :NEW.CountrySubdiv_Code
            FROM GEONAMES
            WHERE ID = :NEW.GeoNames_ID;
            
        END IF;
        
        
        BEGIN
            --London should be the Postal Town for appropriate second-order country subdivisions
            SELECT 'London' AS TownName
            INTO :NEW.TownName
            FROM COUNTRYSUBDIV#GBRONSGEOGCODE A
            INNER JOIN GBRONSGEOGCODE B
                ON A.GBRONSGeogCode_ID = B.ID
            INNER JOIN GBRONSGEOGCODE C
                ON B.Parent$GBRONSGeogCode_ID = C.ID
            INNER JOIN GBRONSRGC D
                ON C.GBRONSRGC_ID = D.ID
            WHERE A.Country_ID = :NEW.Country_ID
            AND A.CountrySubdiv_Code = :NEW.CountrySubdiv_Code
            AND C.Name = 'London'
            AND D.Name = 'Regions'
            AND D.Status = 'Current';
            
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
            
            NULL;
            
        END;
        
END;
/

ALTER TRIGGER ADDRESS_BI_TRI ENABLE;
/

/*
--test
SET SERVEROUTPUT ON;

INSERT
INTO ADDRESS
(
    ID,
    Country_ID,
    CountrySubdiv_Code,
    TownName,
    Postcode
)
VALUES
(
    2,
    'GBR',
    NULL,
    'London',
    'W11 4AJ'
);

SELECT *
FROM ADDRESS
WHERE ID = 2;

INSERT
INTO ADDRESS
(
    ID,
    Country_ID,
    CountrySubdiv_Code,
    TownName,
    Postcode
)
VALUES
(
    3,
    'GBR',
    NULL,
    NULL,
    'N22 7AY'
);

SELECT *
FROM ADDRESS
WHERE ID = 3;

INSERT
INTO ADDRESS
(
    ID,
    Country_ID,
    CountrySubdiv_Code,
    TownName,
    Postcode
)
VALUES
(
    4,
    'ZZZ',
    NULL,
    'Cologne',
    NULL
);

SELECT *
FROM ADDRESS
WHERE ID = 4;

INSERT
INTO ADDRESS
(
    ID,
    Country_ID,
    CountrySubdiv_Code,
    TownName,
    Postcode
)
VALUES
(
    5,
    'GBR',
    NULL,
    'Enfield',
    NULL
);

SELECT *
FROM ADDRESS
WHERE ID = 5;
*/