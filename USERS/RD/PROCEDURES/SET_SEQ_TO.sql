CREATE OR REPLACE
PROCEDURE SET_SEQ_TO
(
    pSequence_Name IN VARCHAR2,
    pNewVal IN INTEGER
)
AUTHID CURRENT_USER
AS
    
    nMin_Value INTEGER;
    nIncrement_By INTEGER;
    nCurrVal INTEGER;
    
BEGIN
    --Enable error messages
    --DBMS_OUTPUT.ENABLE(NULL);
    
    --DBMS_OUTPUT.PUT_LINE('Sequence_Name: ' || pSequence_Name); --Display results
    --DBMS_OUTPUT.PUT_LINE(USER);
    --Find the current minimum sequence value and value by which to increment
    EXECUTE IMMEDIATE 'SELECT Min_Value,' || CHR(10) ||
    'Increment_By' || CHR(10) ||
    'FROM USER_SEQUENCES' || CHR(10) ||
    'WHERE Sequence_Name = ''' || ORACLE_NAME(pSequence_Name) || ''''
    INTO nMin_Value,
    nIncrement_By;
    --DBMS_OUTPUT.PUT_LINE ('Min_value: ' || nMin_Value); --Display results
    --DBMS_OUTPUT.PUT_LINE ('Increment_By: ' || nIncrement_By); --Display results
    --Only change the sequence if the new value if larger than the lowest value possible
    IF pNewVal >= nMin_Value THEN
        
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || pSequence_Name || ' MINVALUE 0'; --Change the minimum value to 0 as we will be resetting the sequence first
        EXECUTE IMMEDIATE 'SELECT ' || pSequence_Name || '.NEXTVAL FROM DUAL' INTO nCurrVal; --Find the last value of the current sequence + increment
        --DBMS_OUTPUT.PUT_LINE ('nCurrVal: ' || nCurrVal); --Display results
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || pSequence_Name || ' INCREMENT BY -' || nCurrVal; --Make the increment the negative of this last value
        EXECUTE IMMEDIATE 'SELECT ' || pSequence_Name || '.NEXTVAL FROM DUAL' INTO nCurrVal; --Increment by the above to set the sequence to 0
        --DBMS_OUTPUT.PUT_LINE ('nCurrVal: ' || nCurrVal); --Display results
        
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || pSequence_Name || ' INCREMENT BY ' ||  pNewVal; --Make the increment the value you want
        EXECUTE IMMEDIATE 'SELECT ' || pSequence_Name || '.NEXTVAL FROM DUAL' INTO nCurrVal; --Increment by the above to set the sequence to the new value
        --DBMS_OUTPUT.PUT_LINE ('nCurrVal: ' || nCurrVal); --Display results
        
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || pSequence_Name || ' MINVALUE ' || nMin_Value; --Set the sequence to the original minimum value
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || pSequence_Name || ' INCREMENT BY ' || nIncrement_By; --Set the sequence to the original increment
        
        --DBMS_OUTPUT.PUT_LINE ('Sequence ' || pSequence_Name || ' is now at ' || nCurrVal); --Display results
        
    END IF;
    
END;
/

GRANT EXECUTE ON SET_SEQ_TO TO PUBLIC;

/*
--test
SET SERVEROUTPUT ON;

BEGIN
    
    SET_SEQ_TO('PERSON_SEQ', 6 );
    
END;
/
*/