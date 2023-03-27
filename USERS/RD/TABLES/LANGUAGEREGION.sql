CREATE TABLE TMP_LANGUAGEREGION AS
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
                        WHERE Val1 = 'Type: region'
                        /*AND Val2 IN
                        (
                            --multi-line Comments
                            'Subtag: GB',
                            --multiple Descriptions
                            'Subtag: TR',
                            --has Deprecated
                            'Subtag: AN',
                            --has Preferred-Value
                            'Subtag: BU'
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
FROM TMP_LANGUAGEREGION
GROUP BY DataElement
ORDER BY 1;

Added	305
Comments	6
Deprecated	11
Description	310
Preferred-Value	6*/

/*check for multiple DataElements per ID
SELECT ID,
DataElement
FROM TMP_LANGUAGEREGION
GROUP BY ID,
DataElement
HAVING COUNT(*) > 1;

TR	Description
SZ	Description
CV	Description
CZ	Description*/

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
    'IETF BCP 47 Region Subtag',
    'urn:ietf:bcp:47'
);
--1 row inserted.

COMMIT;

DROP TABLE TMP_LANGUAGEREGION_1 PURGE;

CREATE TABLE TMP_LANGUAGEREGION_1 AS
SELECT UNCANONICALISE_UUID(UUID_VER4) AS LanguageRegion_ID,
UNCANONICALISE_UUID(UUID_VER4) AS RegionSubtag_UUID,
ID AS RegionSubtag,
PreferredRegionSubtag,
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
        FROM TMP_LANGUAGEREGION
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
        'Preferred-Value' AS PreferredRegionSubtag
    )
)
;

INSERT
INTO TMP_LANGUAGEREGION_1
WITH UPPERALPHABET AS
(
    SELECT ASCII,
    CHR(ASCII) AS Chr
    FROM
    (
        SELECT (ASCIIFrom + LEVEL - 1) AS ASCII
        FROM
        (
            SELECT 65 AS ASCIIFrom,
            90 AS ASCIITo
            FROM DUAL
        )
        CONNECT BY LEVEL <= (ASCIITo - ASCIIFrom + 1)
    )
)
SELECT UNCANONICALISE_UUID(UUID_VER4) AS LanguageRegion_ID,
UNCANONICALISE_UUID(UUID_VER4) AS RegionSubtag_UUID,
RegionSubtag,
NULL AS PreferredRegionSubtag,
Name,
DateTimeStart,
NULL AS DateTimeDeprecated,
NULL AS Comments
FROM
(
    SELECT SUBSTR(RegionSubtag, 1, 1) || B.Chr AS RegionSubtag,
    A.Name,
    A.DateTimeStart
    FROM TMP_LANGUAGEREGION_1 A
    CROSS JOIN UPPERALPHABET B
    WHERE INSTR(A.RegionSubtag, '..') > 0
    AND B.Chr >= SUBSTR(A.RegionSubtag, 2, 1)
    AND B.Chr <= SUBSTR(A.RegionSubtag, -1)
)
;
--40 rows inserted.

COMMIT;

INSERT ALL
INTO LANGUAGEREGION
(
    ID,
    LANGUAGEREGION_ID,
    NAME,
    COMMENTS
)
VALUES
(
    LanguageRegion_ID,
    Preferred$LanguageRegion_ID,
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
    LanguageRegion_ID,
    LanguageRegion_ID
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
    RegionSubtag_UUID,
    RegionSubtag,
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
    RegionSubtag_UUID,
    (SELECT ID FROM NAMESPACE WHERE ShorthandPrefix = 'IETF BCP 47 Region Subtag')
)
INTO SCOPEDIDENTIFIERREL
(
    SCOPEDIDENTIFIER_ID,
    SCOPEDIDENTIFIERRELTYPE_ID,
    REL$SCOPEDIDENTIFIER_ID
)
VALUES
(
    LanguageRegion_ID,
    (SELECT ID FROM SCOPEDIDENTIFIERRELTYPE WHERE Name = 'Equivalence'),
    RegionSubtag_UUID
)
SELECT A.LanguageRegion_ID,
B.LanguageRegion_ID AS Preferred$LanguageRegion_ID,
A.Name,
A.RegionSubtag_UUID,
A.RegionSubtag,
CASE
    WHEN A.DateTimeDeprecated < A.DateTimeStart THEN NULL
    ELSE A.DateTimeStart
END AS DateTimeStart,
A.DateTimeDeprecated,
A.Comments
FROM TMP_LANGUAGEREGION_1 A
LEFT OUTER JOIN TMP_LANGUAGEREGION_1 B
    ON A.PreferredRegionSubtag = B.RegionSubtag
WHERE INSTR(A.RegionSubtag, '..') = 0
ORDER BY Preferred$LanguageRegion_ID NULLS FIRST
;
--1,715 rows inserted.

COMMIT;

--add non-primary descriptions
CREATE TABLE TMP_LANGUAGEREGION_DESIGNATIONS AS
SELECT B.LanguageRegion_ID,
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
        FROM TMP_LANGUAGEREGION
        WHERE DataElement = 'Description'
    )
    WHERE Rnk > 1
) A
INNER JOIN TMP_LANGUAGEREGION_1 B
    ON A.ID = B.RegionSubtag
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
    LanguageRegion_ID,
    (
        SELECT ID
        FROM UNIVERSALONTOLOGYCLASS
        WHERE Name = 'Language Region'
    ),
    SortOrder
)
SELECT *
FROM TMP_LANGUAGEREGION_DESIGNATIONS
;
--10 rows inserted.

COMMIT;

DROP TABLE TMP_LANGUAGEREGION_1;
DROP TABLE TMP_LANGUAGEREGION_DESIGNATIONS;
DROP TABLE TMP_LANGUAGEREGION;