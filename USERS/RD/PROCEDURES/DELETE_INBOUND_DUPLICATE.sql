CREATE OR REPLACE
PROCEDURE DELETE_INBOUND_DUPLICATE(gURL IN INBOUND.URL%TYPE)
AS

BEGIN

DELETE
FROM INBOUND
WHERE (URL
, DateTimeX) IN
(
    WITH INBOUND_CURRENT
    AS
    (
        SELECT URL
        , DateTimeX
        , Data
        , RN
        FROM
        (
            SELECT URL
            , DateTimeX
            , Data
            , ROW_NUMBER() OVER (PARTITION BY URL ORDER BY DateTimeX DESC) AS RN
            FROM INBOUND
            WHERE URL = gURL
        )
        WHERE RN = 1
    )
    --
    , INBOUND_PREVIOUS
    AS
    (
        SELECT URL
        , DateTimeX
        , Data
        , RN
        FROM
        (
            SELECT URL
            , DateTimeX
            , Data
            , ROW_NUMBER() OVER (PARTITION BY URL ORDER BY DateTimeX DESC) AS RN
            FROM INBOUND
            WHERE URL = gURL
        )
        WHERE RN = 2
    )
    
    SELECT URL
    , DateTimeX
    FROM INBOUND_CURRENT
    WHERE DBMS_LOB.COMPARE
    (
        Data
        , (
            SELECT Data
            FROM INBOUND_PREVIOUS
        )
    ) = 0
)
;

END DELETE_INBOUND_DUPLICATE;
/