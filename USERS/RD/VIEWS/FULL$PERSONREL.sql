/*
01	Spouse
02	Partner
03	Parent
04	Next-of-Kin
05	Guardian
06	Foster Parent
07	Polygamous Partner
08	Step Parent
09	Child
10	Dependant
11	Non Dependant
*/

CREATE OR REPLACE
VIEW FULL$PERSONREL
AS
SELECT ROWID AS RowID_,
Person_ID,
Rel$Person_ID,
PersonRelType_ID,
DateTimeEnd,
DateTimeStart,
Comments
FROM PERSONREL
--
UNION ALL
--
SELECT A.ROWID AS RowID_,
A.Rel$Person_ID AS Person_ID,
A.Person_ID AS Rel$Person_ID,
CASE
    WHEN B.Name = 'Parent' THEN
    (
        SELECT ID
        FROM PERSONRELTYPE
        WHERE Name = 'Child'
    )
    ELSE A.PersonRelType_ID
END AS PersonRelType_ID,
A.DateTimeEnd,
A.DateTimeStart,
A.Comments
FROM PERSONREL A
INNER JOIN PERSONRELTYPE B
    ON A.PersonRelType_ID = B.ID
WHERE B.Name IN
(
    --Pure reflexive
    'Spouse',
    'Partner',
    'Polygamous Partner',
    --Typed reflexive
    'Parent'
    --Children links not allowed in the schema
    --'Child'
)
WITH READ ONLY;

/*
--test
--Child appears
SELECT *
FROM FULL$PERSONREL
WHERE Person_ID = 3
;

--Spouse and Child appears
SELECT *
FROM FULL$PERSONREL
WHERE Person_ID = 4
;
*/