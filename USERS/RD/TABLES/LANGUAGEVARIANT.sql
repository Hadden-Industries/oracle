CREATE TABLE TMP_LANGUAGEVARIANT AS
SELECT ID,
MIN(FieldNumber) AS FieldNumber,
DataElement,
Val
FROM
(
    SELECT ID,
    FieldNumber,
    CASE DataElement
        WHEN 'CommentsML' THEN 'Comments'
        WHEN 'DescriptionML' THEN 'Description'
        ELSE DataElement
    END AS DataElement,
    REGEXP_REPLACE
    (
        TRIM
        (
            SUBSTR(Val, INSTR(Val, ':') +1)
        ),
        ' {2,}',
        ' '
    ) AS Val
    FROM
    (
        SELECT ID,
        FieldNumber,
        DataElement,
        LISTAGG(Val, '') WITHIN GROUP (ORDER BY FieldNumber) OVER
        (
            PARTITION BY ID,
            CASE
                WHEN DataElement IN ('CommentsML', 'DescriptionML') THEN DataElement
                ELSE FieldNumber || DataElement
            END
        ) AS Val
        FROM
        (
            SELECT ID,
            FieldNumber,
            CASE
                WHEN MultiLine = 'T' THEN LAST_VALUE
                (
                    CASE
                        WHEN MultiLine IN ('CommentsML', 'DescriptionML') THEN MultiLine
                        ELSE NULL
                    END IGNORE NULLS
                ) OVER
                (
                    PARTITION BY ID
                    ORDER BY FieldNumber
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW EXCLUDE CURRENT ROW
                )
                WHEN MultiLine IN ('CommentsML', 'DescriptionML') THEN MultiLine
                ELSE SUBSTR(Val, 1, INSTR(Val, ':') - 1)
            END AS DataElement,
            Val
            FROM
            (
                SELECT ID,
                FieldNumber,
                CASE
                    WHEN LEAD(Val) OVER (PARTITION BY ID ORDER BY FieldNumber) LIKE '  %' THEN CASE
                        WHEN Val LIKE 'Description:%' THEN 'DescriptionML'
                        WHEN Val LIKE 'Comments:%' THEN 'CommentsML'
                        ELSE 'T'
                    END
                    WHEN Val LIKE '  %' THEN 'T'
                    ELSE 'F'
                END AS MultiLine,
                Val
                FROM
                (
                    SELECT SUBSTR(Val2, LENGTHB('Subtag: ')+1) AS ID,
                    FieldNumber,
                    Val
                    FROM
                    (
                        SELECT *
                        FROM E$LANGUAGE_SUBTAG_REGISTRY
                        WHERE Val1 = 'Type: variant'
                        /*AND Val2 IN
                        (
                            --multi-line comments AND description
                            'Subtag: abl1943',
                            --multi-line comments
                            'Subtag: alalc97',
                            --has deprecated
                            'Subtag: arevmda',
                            --multiple prefixes
                            'Subtag: baku1926',
                            --multiple descriptions
                            'Subtag: cornu',
                            --has Preferred-Value
                            'Subtag: heploc'
                        )*/
                    )
                    UNPIVOT
                    (
                        VAL
                        FOR FIELDNUMBER IN
                        (
                            VAL3 AS 3,
                            VAL4 AS 4,
                            VAL5 AS 5,
                            VAL6 AS 6,
                            VAL7 AS 7,
                            VAL8 AS 8,
                            VAL9 AS 9,
                            VAL10 AS 10,
                            VAL11 AS 11,
                            VAL12 AS 12,
                            VAL13 AS 13,
                            VAL14 AS 14,
                            VAL15 AS 15,
                            VAL16 AS 16,
                            VAL17 AS 17,
                            VAL18 AS 18,
                            VAL19 AS 19,
                            VAL20 AS 20
                        )
                    )
                )
            )
        )
    )
)
GROUP BY ID,
DataElement,
Val
ORDER BY ID,
DataElement
;

/*
SELECT DataElement,
COUNT(*)
FROM TMP_LANGUAGEVARIANT
GROUP BY DataElement
ORDER BY 1;

Added	110
Comments	61
Deprecated	3
Description	140
Preferred-Value	1
Prefix	153*/

/*check for multiple DataElements per ID
SELECT ID,
DataElement
FROM TMP_LANGUAGEVARIANT
GROUP BY ID,
DataElement
HAVING COUNT(*) > 1;

ao1990	Prefix
grclass	Prefix
grital	Prefix
nulik	Description
osojs	Description
pahawh2	Prefix
rozaj	Description
synnejyl	Description
aluku	Description
asante	Description
peano	Description
lipaw	Description
ndyuka	Description
nedis	Description
tunumiit	Description
1994	Prefix
arkaika	Description
cornu	Description
kscor	Description
njiva	Description
pinyin	Prefix
unifon	Prefix
biske	Description
baku1926	Prefix
ekavsk	Prefix
grmistr	Prefix
ijekavsk	Prefix
pahawh3	Prefix
pahawh4	Prefix
spanglis	Prefix
fonnapa	Description
rigik	Description
solba	Description*/

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
    'IETF BCP 47 Variant Subtag',
    'urn:ietf:bcp:47'
);
--1 row inserted.

COMMIT;

DROP TABLE TMP_LANGUAGEVARIANT_1 PURGE;

CREATE TABLE TMP_LANGUAGEVARIANT_1 AS
SELECT UNCANONICALISE_UUID(UUID_VER4) AS LanguageVariant_ID,
UNCANONICALISE_UUID(UUID_VER4) AS VariantSubtag_UUID,
ID AS VariantSubtag,
PreferredVariantSubtag,
Name,
DateTimeStart,
DateTimeDeprecated,
Comments
FROM
(
    SELECT ID,
    DataElement,
    Val
    FROM
    (
        SELECT ID,
        FieldNumber,
        DataElement,
        Val,
        RANK() OVER (PARTITION BY ID, DataElement ORDER BY FieldNumber) AS Rnk
        FROM TMP_LANGUAGEVARIANT
        --WHERE ID = 'TR'
    )
    WHERE Rnk = 1
)
PIVOT
(
    MIN(Val)
    FOR DataElement IN
    (
        'Added' AS DateTimeStart,
        'Comments' AS Comments,
        'Deprecated' AS DateTimeDeprecated,
        'Description' AS Name,
        'Preferred-Value' AS PreferredVariantSubtag
    )
)
;

INSERT ALL
INTO LANGUAGEVARIANT
(
    ID,
    LANGUAGEVARIANT_ID,
    NAME,
    COMMENTS
)
VALUES
(
    LanguageVariant_ID,
    Preferred$LanguageVariant_ID,
    Name,
    Comments
)
INTO SCOPEDIDENTIFIER
(
    ID,
    SCOPEDID
)
VALUES
(
    LanguageVariant_ID,
    LanguageVariant_ID
)
INTO SCOPEDIDENTIFIER
(
    ID,
    SCOPEDID,
    DATETIMESTART,
    DATETIMEEND
)
VALUES
(
    VariantSubtag_UUID,
    VariantSubtag,
    DateTimeStart,
    DateTimeDeprecated
)
INTO IDENTIFIERSCOPE
(
    SCOPEDIDENTIFIER_ID,
    NAMESPACE_ID
)
VALUES
(
    VariantSubtag_UUID,
    (SELECT ID FROM NAMESPACE WHERE ShorthandPrefix = 'IETF BCP 47 Variant Subtag')
)
INTO SCOPEDIDENTIFIERREL
(
    SCOPEDIDENTIFIER_ID,
    SCOPEDIDENTIFIERRELTYPE_ID,
    REL$SCOPEDIDENTIFIER_ID
)
VALUES
(
    LanguageVariant_ID,
    (SELECT ID FROM SCOPEDIDENTIFIERRELTYPE WHERE Name = 'Equivalence'),
    VariantSubtag_UUID
)
SELECT A.LanguageVariant_ID,
B.LanguageVariant_ID AS Preferred$LanguageVariant_ID,
A.Name,
A.VariantSubtag_UUID,
A.VariantSubtag,
CASE
    WHEN A.DateTimeDeprecated < A.DateTimeStart THEN NULL
    ELSE A.DateTimeStart
END AS DateTimeStart,
A.DateTimeDeprecated,
A.Comments
FROM TMP_LANGUAGEVARIANT_1 A
LEFT OUTER JOIN TMP_LANGUAGEVARIANT_1 B
    ON A.PreferredVariantSubtag = B.VariantSubtag
ORDER BY Preferred$LanguageVariant_ID NULLS FIRST
;
--550 rows inserted.

COMMIT;

--add non-primary descriptions
CREATE TABLE TMP_LANGUAGEVARIANT_DESIGNATIONS AS
SELECT B.LanguageVariant_ID,
UNCANONICALISE_UUID(UUID_VER4) AS Designation_UUID,
A.Val AS Designation_Sign,
A.Rnk AS SortOrder
FROM
(
    SELECT ID,
    DataElement,
    Val,
    Rnk
    FROM
    (
        SELECT ID,
        FieldNumber,
        DataElement,
        Val,
        RANK() OVER (PARTITION BY ID, DataElement ORDER BY FieldNumber) AS Rnk
        FROM TMP_LANGUAGEVARIANT
        WHERE DataElement = 'Description'
    )
    WHERE Rnk > 1
) A
INNER JOIN TMP_LANGUAGEVARIANT_1 B
    ON A.ID = B.VariantSubtag
;

INSERT ALL
INTO DESIGNATION
(
    ID,
    LANGUAGEIDENTIFICATION_ID,
    SIGN
)
VALUES
(
    Designation_UUID,
    (
        SELECT A.ID
        FROM LANGUAGEIDENTIFICATION A
        INNER JOIN LANGUAGE B
            ON A.Language_ID = B.ID
        WHERE A.LanguageScript_ID IS NULL
        AND A.LanguageRegion_ID IS NULL
        AND B.Name = 'Undetermined'
    ),
    Designation_Sign
)
INTO DESIGNATION#SCOPEDIDENTIFIER
(
    DESIGNATION_ID,
    SCOPEDIDENTIFIER_ID,
    UNIVERSALONTOLOGYCLASS_ID,
    SORTORDER
)
VALUES
(
    Designation_UUID,
    LanguageVariant_ID,
    (
        SELECT ID
        FROM UNIVERSALONTOLOGYCLASS
        WHERE Name = 'Language Variant'
    ),
    SortOrder
)
SELECT *
FROM TMP_LANGUAGEVARIANT_DESIGNATIONS
;
--60 rows inserted.

COMMIT;

--Add prefixes
MERGE
INTO LANGUAGEVARIANT X
USING
(
    SELECT LanguageVariant_ID,
    LISTAGG(Val, ', ') WITHIN GROUP (ORDER BY Rnk) AS IETFBCP47Prefixes
    FROM
    (
        SELECT B.LanguageVariant_ID,
        A.FieldNumber,
        A.Val,
        RANK() OVER (PARTITION BY B.LanguageVariant_ID ORDER BY A.FieldNumber) AS Rnk
        FROM TMP_LANGUAGEVARIANT A
        INNER JOIN TMP_LANGUAGEVARIANT_1 B
            ON A.ID = B.VariantSubtag
        WHERE A.DataElement = 'Prefix'
    )
    GROUP BY LanguageVariant_ID
) Y
    ON (X.ID = Y.LanguageVariant_ID)
WHEN MATCHED THEN UPDATE SET X.IETFBCP47Prefixes = Y.IETFBCP47Prefixes
;
--103 rows merged.

COMMIT;

DROP TABLE TMP_LANGUAGEVARIANT_DESIGNATIONS;
DROP TABLE TMP_LANGUAGEVARIANT_1;
DROP TABLE TMP_LANGUAGEVARIANT;