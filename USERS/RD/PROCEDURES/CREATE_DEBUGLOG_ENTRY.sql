CREATE OR REPLACE
PROCEDURE CREATE_DEBUGLOG_ENTRY
(
    ObjectName DEBUGLOG.ObjectName%TYPE,
    Comments DEBUGLOG.Comments%TYPE,
    DBMSObjectType_Code DBMSOBJECTTYPE.CODE%TYPE DEFAULT 11
)
AS
    
    PRAGMA AUTONOMOUS_TRANSACTION;
    
BEGIN
    
    INSERT
    INTO DEBUGLOG
    (
        DBMS_ID,
        DBMSOBJECTTYPE_CODE,
        OBJECTNAME,
        USERNAME,
        --DATETIMECREATED,
        COMMENTS
    )
    VALUES
    (
        'O',
        DBMSObjectType_Code,
        ObjectName,
        USER,
        Comments
    );
    
    COMMIT;
    
END;
/

/*
--test
BEGIN
    
    CREATE_DEBUGLOG_ENTRY('RANDOM', 'Stuff happened');
    
END;
/
*/