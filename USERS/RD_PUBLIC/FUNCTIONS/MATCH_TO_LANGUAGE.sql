CREATE OR REPLACE
FUNCTION MATCH_TO_LANGUAGE(g_LanguageCode IN VARCHAR2)
RETURN LANGUAGE.ID%TYPE
PARALLEL_ENABLE
DETERMINISTIC
AS

    PRAGMA UDF;

    l_Language_ID LANGUAGE.ID%TYPE := NULL;

BEGIN

    BEGIN

        SELECT Language_ID
        INTO l_Language_ID
        FROM
        (
            SELECT D.ScopedIdentifier_ID AS Language_ID,
            ROW_NUMBER() OVER (ORDER BY A.ShorthandPrefix) AS RowNumber
            FROM NAMESPACE A
            INNER JOIN IDENTIFIERSCOPE B
                ON A.ID = B.Namespace_ID
            INNER JOIN SCOPEDIDENTIFIER C
                ON B.ScopedIdentifier_ID = C.ID
            INNER JOIN SCOPEDIDENTIFIERREL D
                ON C.ID = D.Rel$ScopedIdentifier_ID
            INNER JOIN SCOPEDIDENTIFIERRELTYPE E
                ON D.ScopedIdentifierRelType_ID = E.ID
            WHERE A.ShorthandPrefix IN
            (
                'ISO 639-1 Code',
                'ISO 639-2 Bibliographic Applications Code',
                'ISO 639-2 Terminology Applications Code',
                'ISO 639-3 Code',
                'ISO 639-6 Code'
            )
            AND C.ScopedID = g_LanguageCode
            AND E.Name = 'Equivalence'
        )
        WHERE RowNumber = 1;

    EXCEPTION
    WHEN NO_DATA_FOUND THEN

        SELECT ID
        INTO l_Language_ID
        FROM LANGUAGE
        WHERE Name = 'Undetermined';

    END;

    RETURN l_Language_ID;
    
END;
/

/*
--test
SELECT MATCH_TO_LANGUAGE('es')
FROM DUAL;
*/