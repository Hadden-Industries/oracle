SELECT *
FROM LANGUAGEIDENTIFICATION
;

CREATE TABLE TMP_LANGUAGEIDENTIFICATION AS
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
TMP_LANGUAGE_ISO639P13 AS
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
    FROM SCOPEDIDENTIFIER AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) A
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
),
TMP_SUBTAGVARIANT AS
(
    SELECT B.ScopedIdentifier_ID AS LanguageVariant_ID,
    A.ScopedID
    FROM SCOPEDIDENTIFIER AS OF PERIOD FOR VALID_TIME SYS_EXTRACT_UTC(SYSTIMESTAMP) A
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
SELECT FullTag,
UNCANONICALISE_UUID(UUID_VER4) AS LanguageIdentification_ID,
MIN(Language_ID) AS Language_ID,
MIN(LanguageScript_ID) AS LanguageScript_ID,
MIN(LanguageRegion_ID) AS LanguageRegion_ID,
MIN(LanguageVariant_ID) AS LanguageVariant_ID
FROM
(
    SELECT A.*,
    COALESCE(B.Language_ID, C.Language_ID) AS Language_ID,
    D.LanguageScript_ID,
    E.LanguageRegion_ID,
    F.LanguageVariant_ID
    FROM
    (
        SELECT A.Language_Name,
        B.Position AS FullTagPosition,
        TRIM(B.Text) AS FullTag,
        C.Position AS SubTagPosition,
        TRIM(C.Text) AS SubTag
        FROM E$MICROSOFTSTORESUPPORTEDLANGUAGES A
        JOIN TABLE(SPLIT(SUPPORTED_LANGUAGE_CODES)) B
            ON 1 = 1
        JOIN TABLE(SPLIT(TRIM(B.Text), '-')) C
            ON 1 = 1
        --WHERE A.Language_Name = 'Norwegian'
    ) A
    LEFT OUTER JOIN TMP_LANGUAGE_ISO639P1 B
        ON A.SubTag = B.ScopedID
            AND A.SubTagPosition = 1
    LEFT OUTER JOIN TMP_LANGUAGE_ISO639P3 C
        ON A.SubTag = C.ScopedID
            AND A.SubTagPosition = 1
    LEFT OUTER JOIN TMP_SUBTAGSCRIPT D
        ON LOWER(A.SubTag) = LOWER(D.ScopedID)
            AND A.SubTagPosition != 1
    LEFT OUTER JOIN TMP_SUBTAGREGION E
        ON LOWER(A.SubTag) = LOWER(E.ScopedID)
            AND A.SubTagPosition != 1
    LEFT OUTER JOIN TMP_SUBTAGVARIANT F
        ON LOWER(A.SubTag) = LOWER(F.ScopedID)
            AND A.SubTagPosition != 1
    --cs region does not exist in the subtag registry
    WHERE A.FullTag NOT IN ('sr-cyrl-cs', 'sr-latn-cs')
)
GROUP BY FullTag
--HAVING COALESCE(MIN(Language_ID), MIN(LanguageScript_ID), MIN(LanguageRegion_ID), MIN(LanguageVariant_ID)) IS NULL
ORDER BY FullTag
;

INSERT ALL
WHEN Language_ID IS NOT NULL THEN
INTO LANGUAGEIDENTIFICATION
(
    ID,
    LANGUAGE_ID,
    LANGUAGESCRIPT_ID,
    LANGUAGEREGION_ID,
    COMMENTS
)
VALUES
(
    LanguageIdentification_ID,
    Language_ID,
    LanguageScript_ID,
    LanguageRegion_ID,
    FullTag
)
WHEN LanguageVariant_ID IS NOT NULL THEN
INTO LANGUAGEIDENTIFICATIONVARIANT
(
    LANGUAGEIDENTIFICATION_ID,
    LANGUAGEVARIANT_ID,
    SORTORDER
)
VALUES
(
    LanguageIdentification_ID,
    LanguageVariant_ID,
    1
)
SELECT *
FROM TMP_LANGUAGEIDENTIFICATION
--used this to filter for where all language-only tags were added already
--WHERE COALESCE(LanguageScript_ID,LanguageRegion_ID,LanguageVariant_ID) IS NOT NULL
;
--265 rows inserted.

COMMIT;

DROP TABLE TMP_LANGUAGEIDENTIFICATION;

INSERT
INTO NAMESPACE
(
    OneNamePerItemIndicator,
    OneItemPerNameIndicator,
    MandatoryNamingConventionInd,
    ShorthandPrefix,
    SchemeReference
)
VALUES
(
    'F',
    'T',
    'T',
    'IETF BCP 47 Language Tag',
    'urn:ietf:bcp:47'
);
--1 row inserted.

COMMIT;

INSERT
INTO SCOPEDIDENTIFIER
(
    ID,
    SCOPEDID
)
SELECT ID,
ID
FROM LANGUAGEIDENTIFICATION
WHERE (ID, ID) NOT IN
(
    SELECT ID,
    ScopedID
    FROM SCOPEDIDENTIFIER
);

--26,933 rows inserted.

COMMIT;

INSERT ALL
INTO SCOPEDIDENTIFIER
(
    ID,
    SCOPEDID
)
VALUES
(
    ScopedIdentifier_ID,
    ScopedID
)
INTO IDENTIFIERSCOPE
(
    SCOPEDIDENTIFIER_ID,
    NAMESPACE_ID
)
VALUES
(
    ScopedIdentifier_ID,
    (SELECT ID FROM NAMESPACE WHERE ShorthandPrefix = 'IETF BCP 47 Language Tag')
)
INTO SCOPEDIDENTIFIERREL
(
    SCOPEDIDENTIFIER_ID,
    SCOPEDIDENTIFIERRELTYPE_ID,
    REL$SCOPEDIDENTIFIER_ID
)
VALUES
(
    LanguageIdentification_IID,
    (SELECT ID FROM SCOPEDIDENTIFIERRELTYPE WHERE Name = 'Equivalence'),
    ScopedIdentifier_ID
)
--materialize because the function gives a different UUID for each insert otherwise...
WITH Q AS
(
    SELECT /*+ MATERIALIZE */
    UNCANONICALISE_UUID(UUID_VER4) AS ScopedIdentifier_ID,
    ID AS LanguageIdentification_IID,
    TO_LANGUAGE_TAG(ID) AS ScopedID
    FROM LANGUAGEIDENTIFICATION
    WHERE
    (
        COMMENTS IS NOT NULL
    )
    OR
    (
        Language_ID IN
        (
            SELECT A.ScopedIdentifier_ID
            FROM SCOPEDIDENTIFIERREL A
            INNER JOIN SCOPEDIDENTIFIERRELTYPE B
                ON A.ScopedIdentifierRelType_ID = B.ID
            INNER JOIN SCOPEDIDENTIFIER C
                ON A.Rel$ScopedIdentifier_ID = C.ID
            INNER JOIN IDENTIFIERSCOPE D
                ON C.ID = D.ScopedIdentifier_ID
            INNER JOIN NAMESPACE E
                ON D.Namespace_ID = E.ID
            WHERE B.Name = 'Equivalence'
            AND E.ShorthandPrefix = 'ISO 639-1 Code'
            AND C.ScopedID IN
            (
                SELECT SUBSTRB(Comments, 1, INSTRB(Comments, '-') - 1)
                FROM LANGUAGEIDENTIFICATION
                WHERE Comments IS NOT NULL
            )
        )
        AND LanguageScript_ID IS NULL
        AND LanguageRegion_ID IS NULL
    )
)
SELECT *
FROM Q;
--1074 rows inserted.

COMMIT;

--test
WITH IETFBCP47LANGUAGETAGS AS
(
    SELECT A.ScopedIdentifier_ID,
    C.ScopedID
    FROM SCOPEDIDENTIFIERREL A
    INNER JOIN SCOPEDIDENTIFIERRELTYPE B
        ON A.ScopedIdentifierRelType_ID = B.ID
    INNER JOIN SCOPEDIDENTIFIER C
        ON A.Rel$ScopedIdentifier_ID = C.ID
    INNER JOIN IDENTIFIERSCOPE D
        ON C.ID = D.ScopedIdentifier_ID
    INNER JOIN NAMESPACE E
        ON D.Namespace_ID = E.ID
    WHERE B.Name = 'Equivalence'
    AND E.ShorthandPrefix = 'IETF BCP 47 Language Tag'
)
SELECT A.*,
B.ScopedID AS Code
FROM LANGUAGEIDENTIFICATION A
LEFT OUTER JOIN IETFBCP47LANGUAGETAGS B
    ON A.ID = B.ScopedIdentifier_ID
;