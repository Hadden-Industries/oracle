CREATE OR REPLACE
FUNCTION TO_LANGUAGE_TAG
(
    gLanguageIdentification_ID IN LANGUAGEIDENTIFICATION.ID%TYPE
)
RETURN VARCHAR2
DETERMINISTIC PARALLEL_ENABLE
AS
    
    PRAGMA UDF;
    
    lLanguage_Tag VARCHAR2(4000 BYTE);
    lLanguage_Variant_Subtags VARCHAR2(4000 BYTE);
    
BEGIN
    
    WITH TMP_LANGUAGE_ISO639P1 AS
    (
        SELECT B.ScopedIdentifier_ID AS Language_ID,
        A.ScopedID
        FROM SCOPEDIDENTIFIER A
        INNER JOIN SCOPEDIDENTIFIERREL B
            ON A.ID = B.Rel$ScopedIdentifier_ID
        WHERE A.ID IN
        (
            SELECT ScopedIdentifier_ID
            FROM IDENTIFIERSCOPE
            WHERE Namespace_ID =
            (
                SELECT ID
                FROM NAMESPACE
                WHERE ShorthandPrefix = 'ISO 639-1 Code'
            )
        )
        AND B.ScopedIdentifierRelType_ID = 
        (
            SELECT ID
            FROM SCOPEDIDENTIFIERRELTYPE
            WHERE Name = 'Equivalence'
        )
    ),
    TMP_LANGUAGE_ISO639P3 AS
    (
        SELECT B.ScopedIdentifier_ID AS Language_ID,
        A.ScopedID
        FROM SCOPEDIDENTIFIER A
        INNER JOIN SCOPEDIDENTIFIERREL B
            ON A.ID = B.Rel$ScopedIdentifier_ID
        WHERE A.ID IN
        (
            SELECT ScopedIdentifier_ID
            FROM IDENTIFIERSCOPE
            WHERE Namespace_ID =
            (
                SELECT ID
                FROM NAMESPACE
                WHERE ShorthandPrefix = 'ISO 639-3 Code'
            )
        )
        AND B.ScopedIdentifierRelType_ID = 
        (
            SELECT ID
            FROM SCOPEDIDENTIFIERRELTYPE
            WHERE Name = 'Equivalence'
        )
    ),
    TMP_SUBTAGSCRIPT AS
    (
        SELECT B.ScopedIdentifier_ID AS LanguageScript_ID,
        A.ScopedID
        FROM SCOPEDIDENTIFIER A
        INNER JOIN SCOPEDIDENTIFIERREL B
            ON A.ID = B.Rel$ScopedIdentifier_ID
        WHERE A.ID IN
        (
            SELECT ScopedIdentifier_ID
            FROM IDENTIFIERSCOPE
            WHERE Namespace_ID =
            (
                SELECT ID
                FROM NAMESPACE
                WHERE ShorthandPrefix = 'ISO 15924 Code'
            )
        )
        AND B.ScopedIdentifierRelType_ID = 
        (
            SELECT ID
            FROM SCOPEDIDENTIFIERRELTYPE
            WHERE Name = 'Equivalence'
        )
    ),
    TMP_SUBTAGREGION AS
    (
        SELECT B.ScopedIdentifier_ID AS LanguageRegion_ID,
        A.ScopedID
        FROM SCOPEDIDENTIFIER A
        INNER JOIN SCOPEDIDENTIFIERREL B
            ON A.ID = B.Rel$ScopedIdentifier_ID
        WHERE A.ID IN
        (
            SELECT ScopedIdentifier_ID
            FROM IDENTIFIERSCOPE
            WHERE Namespace_ID =
            (
                SELECT ID
                FROM NAMESPACE
                WHERE ShorthandPrefix = 'IETF BCP 47 Region Subtag'
            )
        )
        AND B.ScopedIdentifierRelType_ID = 
        (
            SELECT ID
            FROM SCOPEDIDENTIFIERRELTYPE
            WHERE Name = 'Equivalence'
        )
    )
    SELECT LanguageSubtag
    || CASE
        WHEN ScriptSubtag IS NOT NULL THEN '-' || ScriptSubtag
        ELSE NULL
    END
    || CASE
        WHEN RegionSubtag IS NOT NULL THEN '-' || RegionSubtag
        ELSE NULL
    END
    INTO lLanguage_Tag
    FROM
    (
        SELECT COALESCE(B.ScopedID, C.ScopedID) AS LanguageSubtag,
        D.ScopedID AS ScriptSubtag,
        E.ScopedID AS RegionSubtag
        FROM LANGUAGEIDENTIFICATION A
        LEFT OUTER JOIN TMP_LANGUAGE_ISO639P1 B
            ON A.Language_ID = B.Language_ID
        LEFT OUTER JOIN TMP_LANGUAGE_ISO639P3 C
            ON A.Language_ID = C.Language_ID
        LEFT OUTER JOIN TMP_SUBTAGSCRIPT D
            ON A.LanguageScript_ID = D.LanguageScript_ID
        LEFT OUTER JOIN TMP_SUBTAGREGION E
            ON A.LanguageRegion_ID = E.LanguageRegion_ID
        WHERE A.ID = gLanguageIdentification_ID
    );

    WITH TMP_LANGUAGE_VARIANTS AS
    (
        SELECT B.ScopedIdentifier_ID AS LanguageVariant_ID,
        A.ScopedID
        FROM SCOPEDIDENTIFIER A
        INNER JOIN SCOPEDIDENTIFIERREL B
            ON A.ID = B.Rel$ScopedIdentifier_ID
        WHERE A.ID IN
        (
            SELECT ScopedIdentifier_ID
            FROM IDENTIFIERSCOPE
            WHERE Namespace_ID =
            (
                SELECT ID
                FROM NAMESPACE
                WHERE ShorthandPrefix = 'IETF BCP 47 Variant Subtag'
            )
        )
        AND B.ScopedIdentifierRelType_ID = 
        (
            SELECT ID
            FROM SCOPEDIDENTIFIERRELTYPE
            WHERE Name = 'Equivalence'
        )
    )
    SELECT LISTAGG(VariantSubtag, '-') WITHIN GROUP (ORDER BY SortOrder) AS VariantSubtags
    INTO lLanguage_Variant_Subtags
    FROM
    (
        SELECT B.ScopedID AS VariantSubtag,
        A.SortOrder
        FROM LANGUAGEIDENTIFICATIONVARIANT A
        LEFT OUTER JOIN TMP_LANGUAGE_VARIANTS B
            ON A.LanguageVariant_ID = B.LanguageVariant_ID
        WHERE A.LanguageIdentification_ID = gLanguageIdentification_ID
    );
    
    RETURN lLanguage_Tag
    || CASE
        WHEN lLanguage_Variant_Subtags IS NOT NULL THEN '-' || lLanguage_Variant_Subtags
        ELSE NULL
    END;
    
END;
/


/*
--test
SELECT LANGUAGEIDENTIFICATION.*,
TO_LANGUAGE_TAG(ID)
FROM LANGUAGEIDENTIFICATION
WHERE Comments IS NOT NULL
--AND LOWER(TO_LANGUAGE_TAG(ID)) != LOWER(COMMENTS)
;
*/