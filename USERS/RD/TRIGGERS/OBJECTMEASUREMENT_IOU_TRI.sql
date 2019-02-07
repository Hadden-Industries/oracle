CREATE OR REPLACE
TRIGGER OBJECTMEASUREMENT_IOU_TRI
INSTEAD OF UPDATE
ON OBJECTMEASUREMENT
FOR EACH ROW

DECLARE

    rEvent EVENT%ROWTYPE;
    rMeasuredQuantityValue MEASUREDQUANTITYVALUE%ROWTYPE;
    rMeasurement MEASUREMENT%ROWTYPE;
    rMeasurementResult MEASUREMENTRESULT%ROWTYPE;

BEGIN

    SELECT *
    INTO rEvent
    FROM EVENT
    WHERE ID = :OLD.ID;

    IF rEvent.DateTimeStart != :NEW.DATETIMESTART THEN

        UPDATE EVENT
        SET DateTimeStart = :NEW.DATETIMESTART
        WHERE ID = rEvent.ID;

    END IF;

    IF rEvent.DateTimeEnd != :NEW.DATETIMEEND THEN

        UPDATE EVENT
        SET DateTimeEnd = :NEW.DATETIMEEND
        WHERE ID = rEvent.ID;

    END IF;

    IF COALESCE(rEvent.Comments, CHR(0)) != COALESCE(:NEW.COMMENTS, CHR(0)) THEN

        UPDATE EVENT
        SET Comments = :NEW.COMMENTS
        WHERE ID = rEvent.ID;

    END IF;

    SELECT *
    INTO rMeasurement
    FROM MEASUREMENT
    WHERE Event_ID = :OLD.ID;

    IF COALESCE(rMeasurement.MeasurementMethod_ID, -1) != COALESCE(:NEW.MEASUREMENTMETHOD_ID, -1) THEN

        UPDATE MEASUREMENT
        SET MeasurementMethod_ID = :NEW.MEASUREMENTMETHOD_ID
        WHERE Event_ID = rMeasurement.Event_ID;

    END IF;
    
    IF rMeasurement.Quantity_ID != :NEW.QUANTITY_ID THEN

        UPDATE MEASUREMENT
        SET Quantity_ID = :NEW.QUANTITY_ID
        WHERE Event_ID = rMeasurement.Event_ID;

    END IF;

    SELECT *
    INTO rMeasurementResult
    FROM MEASUREMENTRESULT
    WHERE Event_ID = :OLD.ID;

    IF COALESCE(rMeasurementResult.NumberDataPoint, -1) != COALESCE(:NEW.NUMBERDATAPOINT, -1) THEN

        UPDATE MEASUREMENTRESULT
        SET NumberDataPoint = :NEW.NUMBERDATAPOINT
        WHERE ID = rMeasurementResult.ID;

    END IF;

    IF COALESCE(rMeasurementResult.StandardMeasurementUncertainty, -1) != COALESCE(:NEW.STANDARDMEASUREMENTUNCERTAINTY, -1) THEN

        UPDATE MEASUREMENTRESULT
        SET StandardMeasurementUncertainty = :NEW.STANDARDMEASUREMENTUNCERTAINTY
        WHERE ID = rMeasurementResult.ID;

    END IF;

    SELECT *
    INTO rMeasuredQuantityValue
    FROM MEASUREDQUANTITYVALUE
    WHERE MeasurementResult_ID =
    (
        SELECT ID
        FROM MEASUREMENTRESULT
        WHERE Event_ID = :OLD.ID
    );

    IF rMeasuredQuantityValue.MeasurementUnit_ID != :NEW.MEASUREMENTUNIT_ID THEN

        UPDATE MEASUREDQUANTITYVALUE
        SET MeasurementUnit_ID = :NEW.MEASUREMENTUNIT_ID
        WHERE ID = rMeasuredQuantityValue.ID;

    END IF;

    IF rMeasuredQuantityValue.NumericalQuantityValue != :NEW.NUMERICALQUANTITYVALUE THEN

        UPDATE MEASUREDQUANTITYVALUE
        SET NumericalQuantityValue = :NEW.NUMERICALQUANTITYVALUE
        WHERE ID = rMeasuredQuantityValue.ID;

    END IF;

END;
/

/*
--test
UPDATE OBJECTMEASUREMENT
SET DateTimeStart = DATE'2000-01-01',
Comments = 'Testing update',
NumericalQuantityValue = 80
WHERE ID = 54;

SELECT *
FROM OBJECTMEASUREMENT
WHERE ID = 54;

ROLLBACK;
*/