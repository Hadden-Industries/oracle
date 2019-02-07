CREATE OR REPLACE 
PACKAGE BODY EVENT_UTIL
AS
    
    --Global package variables
    
    PROCEDURE DELETE
    (
        p_ID IN EVENT.ID%TYPE
    )
    AS
        
        l_EventType_Name EVENTTYPE.Name%TYPE;
        
    BEGIN
        
        SELECT Name
        INTO l_EventType_Name
        FROM EVENTTYPE
        WHERE ID =
        (
            SELECT EventType_ID
            FROM EVENT
            WHERE ID = p_ID
        );
        
        IF (l_EventType_Name = 'Achievement Earned') THEN
            
            DELETE
            FROM ACHIEVEMENTEARNED
            WHERE Event_ID = p_ID;
            
        ELSIF (l_EventType_Name = 'Exercise Set') THEN
            
            DELETE
            FROM EXERCISESET
            WHERE Event_ID = p_ID;
            
        ELSIF (l_EventType_Name = 'Measurement') THEN
            
            DELETE
            FROM MEASUREDQUANTITYVALUE
            WHERE MeasurementResult_ID IN
            (
                SELECT ID
                FROM MEASUREMENTRESULT
                WHERE Event_ID = p_ID
            );
            
            DELETE
            FROM MEASUREMENTRESULT
            WHERE Event_ID = p_ID;
            
            DELETE
            FROM MEASUREMENT
            WHERE Event_ID = p_ID;
            
        ELSIF (l_EventType_Name = 'Meal') THEN
            
            DELETE
            FROM MEAL
            WHERE Event_ID = p_ID;
           
        ELSIF (l_EventType_Name = 'Workout') THEN
            
            DELETE
            FROM WORKOUT
            WHERE Event_ID = p_ID;
            
        END IF;
        
        DELETE
        FROM EVENTREL
        WHERE Event_ID = p_ID;
        
        DELETE
        FROM EVENTREL
        WHERE Rel$Event_ID = p_ID;
        
        DELETE
        FROM EVENT#OBJECT
        WHERE Event_ID = p_ID;
        
        DELETE
        FROM EVENT#PERSON
        WHERE Event_ID = p_ID;
        
        DELETE
        FROM EVENT
        WHERE ID = p_ID;
        
    END;
    
END;
/