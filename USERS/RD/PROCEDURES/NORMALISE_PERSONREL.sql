CREATE OR REPLACE
PROCEDURE NORMALISE_PERSONREL
AS
    
    
    
BEGIN
    
    --Convert 'Child' rows into 'Parent' rows where they do not already exist
    INSERT
    INTO PERSONREL
    (
        PERSON_ID,
        PERSONRELTYPE_ID,
        REL$PERSON_ID
    )
    --
    SELECT Person_ID,
    PersonRelType_ID,
    Rel$Person_ID
    FROM
    (
        SELECT Rel$Person_ID AS Person_ID,
        (
            SELECT ID
            FROM PERSONRELTYPE
            WHERE Name = 'Parent'
        ) AS PersonRelType_ID,
        Person_ID AS Rel$Person_ID
        FROM PERSONREL
        WHERE PersonRelType_ID =
        (
            SELECT ID
            FROM PERSONRELTYPE
            WHERE Name = 'Child'
        )
    )
    WHERE Person_ID IS NOT NULL
    AND PersonRelType_ID IS NOT NULL
    AND Rel$Person_ID IS NOT NULL
    AND
    (
        Person_ID,
        PersonRelType_ID,
        Rel$Person_ID
    ) NOT IN
    (
        SELECT Person_ID,
        PersonRelType_ID,
        Rel$Person_ID
        FROM PERSONREL
    );
    
    --Delete all 'Child' rows
    DELETE
    FROM PERSONREL
    WHERE PersonRelType_ID =
    (
        SELECT ID
        FROM PERSONRELTYPE
        WHERE Name = 'Child'
    );
    
    --Delete duplicate relationships
    DELETE
    FROM PERSONREL
    WHERE ROWID IN
    (
        SELECT ROWID
        FROM
        (
            SELECT A.ROWID,
            Person_ID,
            Rel$Person_ID,
            PersonRelType_ID,
            ROW_NUMBER()
            OVER
            (
                PARTITION BY CASE
                    WHEN Person_ID > Rel$Person_ID THEN Rel$Person_ID
                    ELSE Person_ID
                END,
                CASE
                    WHEN Person_ID > Rel$Person_ID THEN Person_ID
                    ELSE Rel$Person_ID
                END,
                PersonRelType_ID
                ORDER BY Person_ID
            ) AS RN
            FROM PERSONREL A
            INNER JOIN PERSONRELTYPE B
                ON A.PersonRelType_ID = B.ID
            WHERE B.Name IN
            (
                --Purely reflexive
                'Spouse',
                'Partner',
                'Polygamous Partner'
            )
        )
        WHERE RN > 1
    );
    
END;
/