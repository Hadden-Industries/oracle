CREATE OR REPLACE
TRIGGER OBJECTMEASUREMENT_IOI_TRI
INSTEAD OF INSERT
ON OBJECTMEASUREMENT
FOR EACH ROW

DECLARE

    nEvent_ID EVENT.ID%TYPE;
    nMeasurementResult_ID MEASUREMENTRESULT.ID%TYPE;

BEGIN

    IF :NEW.ID IS NULL THEN

        INSERT
        INTO EVENT
        (
            EVENTTYPE_ID,
            NAME,
            UUID,
            DATETIMESTART,
            DATETIMEEND,
            DATETIMECREATED,
            DATETIMEDELETED,
            COMMENTS
        )
        --
        VALUES
        (
            (
                SELECT ID
                FROM EVENTTYPE
                WHERE Name = 'Measurement'
            ),
            :NEW.NAME,
            :NEW.UUID,
            :NEW.DATETIMESTART,
            :NEW.DATETIMEEND,
            :NEW.DATETIMECREATED,
            :NEW.DATETIMEDELETED,
            :NEW.COMMENTS
        ) RETURNING ID INTO nEvent_ID;

    ELSE

        nEvent_ID := :NEW.ID;

    END IF;

    IF :NEW.PERSON_ID IS NOT NULL THEN

        INSERT
        INTO EVENT#PERSON
        (
            EVENT_ID,
            PERSON_ID,
            EVENTTOPERSONTYPE_ID,
            DATETIMECREATED
        )
        --
        VALUES
        (
            nEvent_ID,
            :NEW.PERSON_ID,
            (
                SELECT ID
                FROM EVENTTOPERSONTYPE
                WHERE Name = 'Creator'
            ),
            :NEW.DATETIMECREATED
        );

    END IF;

    INSERT
    INTO EVENT#OBJECT
    (
        EVENT_ID,
        OBJECT_ID,
        EVENTTOOBJECTTYPE_ID,
        DATETIMECREATED
    )
    --
    VALUES
    (
        nEvent_ID,
        :NEW.OBJECT_ID,
        (
            SELECT ID
            FROM EVENTTOOBJECTTYPE
            WHERE Name = 'Measured Object'
        ),
        :NEW.DATETIMECREATED
    );

    INSERT
    INTO MEASUREMENT
    (
        EVENT_ID,
        MEASUREMENTMETHOD_ID,
        QUANTITY_ID,
        DATETIMECREATED
    )
    --
    VALUES
    (
        nEvent_ID,
        :NEW.MEASUREMENTMETHOD_ID,
        :NEW.QUANTITY_ID,
        :NEW.DATETIMECREATED
    );

    INSERT
    INTO MEASUREMENTRESULT
    (
        EVENT_ID,
        NUMBERDATAPOINT,
        STANDARDMEASUREMENTUNCERTAINTY,
        DATETIMECREATED
    )
    --
    VALUES
    (
        nEvent_ID,
        :NEW.NUMBERDATAPOINT,
        :NEW.STANDARDMEASUREMENTUNCERTAINTY,
        :NEW.DATETIMECREATED
    ) RETURNING ID INTO nMeasurementResult_ID;

    INSERT
    INTO MEASUREDQUANTITYVALUE
    (
        MEASUREMENTRESULT_ID,
        MEASUREMENTUNIT_ID,
        NUMERICALQUANTITYVALUE,
        DATETIMECREATED
    )
    --
    VALUES
    (
        nMeasurementResult_ID,
        :NEW.MEASUREMENTUNIT_ID,
        :NEW.NUMERICALQUANTITYVALUE,
        :NEW.DATETIMECREATED
    );

END;
/

/*
--test
INSERT
INTO OBJECTMEASUREMENT
(
    MEASUREMENTMETHOD_ID,
    MEASUREMENTUNIT_ID,
    OBJECT_ID,
    PERSON_ID,
    QUANTITY_ID,
    NAME,
    NUMERICALQUANTITYVALUE,
    DATETIMESTART,
    DATETIMECREATED,
    COMMENTS
)
VALUES
(
    1,
    DATE'2000-01-01',
    1.75,
    'Test value',
    'MTR'
);

ROLLBACK;
*/