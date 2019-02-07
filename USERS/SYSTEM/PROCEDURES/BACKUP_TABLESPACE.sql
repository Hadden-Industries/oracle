SET SERVEROUTPUT ON;

CREATE OR REPLACE
PROCEDURE BACKUP_TABLESPACE
(
    gTableSpaceName VARCHAR2
)
AS
    
    l_datapump_handle NUMBER;
    l_directory VARCHAR2(30);
    l_directory_path VARCHAR2(4000 BYTE);
    l_job_state VARCHAR2(30) := 'UNDEFINED';
    l_job_status KU$_JOBSTATUS;
    l_log_entry KU$_LOGENTRY;
    l_loop_index PLS_INTEGER := 0;
    l_percentage_done NUMBER := 0;
    l_scheduler_job_name VARCHAR2(30);
    l_status KU$_STATUS;
    l_tablespace_name VARCHAR2(30);
    
BEGIN
    
    --Validate that the tablespace exists
    SELECT TableSpace_Name,
    TableSpace_Name || '_BACKUP'
    INTO l_tablespace_name,
    l_directory
    FROM USER_TABLESPACES
    WHERE TableSpace_Name = UPPER
    (
        TRIM(gTableSpaceName)
    );
    
    SELECT Directory_Path
    || TO_CHAR
    (
        SYS_EXTRACT_UTC(SYSTIMESTAMP),
        'YYYY-MM-DD'
    )
    INTO l_directory_path
    FROM ALL_DIRECTORIES
    WHERE Directory_Name = 'E_ORACLE';
    
    BEGIN
        
        EXECUTE IMMEDIATE('DROP DIRECTORY ' || l_directory);
        
    EXCEPTION
    WHEN OTHERS THEN
        
        DBMS_OUTPUT.Put_Line(SQLErrM);
        
    END;
    
    l_scheduler_job_name := 'CREATE_' || l_directory;
    
    DBMS_SCHEDULER.Create_Job
    (
        job_name => l_scheduler_job_name,
        job_type => 'EXECUTABLE',
        job_action => '/usr/bin/mkdir',
        number_of_arguments => 1,
        enabled => FALSE,
        auto_drop => TRUE
    );
    
    DBMS_SCHEDULER.Set_Job_Argument_Value
    (
        l_scheduler_job_name,
        1,
        l_directory_path
    );
    
    DBMS_SCHEDULER.Run_Job(l_scheduler_job_name);
    
    EXECUTE IMMEDIATE('CREATE DIRECTORY ' || l_directory || ' AS ''' || l_directory_path || '''');
    
    BEGIN
        
        EXECUTE IMMEDIATE('ALTER TABLESPACE ' || l_tablespace_name || ' READ ONLY');
        
    EXCEPTION
    WHEN OTHERS THEN
        
        DBMS_OUTPUT.Put_Line(SQLErrM);
        
    END;
    
    l_datapump_handle := DBMS_DATAPUMP.Open
    (
        operation => 'EXPORT',
        job_mode => 'TRANSPORTABLE',
        remote_link => NULL,
        job_name => NULL,
        version => 'LATEST'
    );
    
    DBMS_DATAPUMP.Add_File
    (
        handle => l_datapump_handle,
        filename => LOWER(l_tablespace_name) || '.dmp',
        directory => l_directory,
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_DUMP_FILE,
        reusefile => 1
    );
    
    DBMS_DATAPUMP.Add_File
    (
        handle => l_datapump_handle,
        filename => LOWER(l_tablespace_name) || '.log',
        directory => l_directory,
        filetype => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE
    );
    
    DBMS_DATAPUMP.Metadata_Filter
    (
        handle => l_datapump_handle,
        name => 'TABLESPACE_EXPR',
        value => '= ''' || l_tablespace_name || ''''
    );
    
    DBMS_DATAPUMP.Set_Parameter
    (
        handle => l_datapump_handle,
        name => 'METRICS',
        value => 1
    );
    
    DBMS_DATAPUMP.Set_Parameter
    (
        handle => l_datapump_handle,
        name => 'TTS_FULL_CHECK',
        value => 1
    );
    
    DBMS_DATAPUMP.Start_Job(l_datapump_handle);
    
    WHILE
    (
        (l_job_state != 'COMPLETED')
        AND
        (l_job_state != 'STOPPED')
    )
    LOOP
        
        DBMS_DATAPUMP.Get_Status
        (
            handle => l_datapump_handle,
            mask => DBMS_DATAPUMP.KU$_Status_Job_Error + DBMS_DATAPUMP.KU$_Status_Job_Status + DBMS_DATAPUMP.KU$_Status_WIP,
            timeout => -1,
            job_state => l_job_state,
            status => l_status
        );
        
        l_job_status := l_status.Job_Status;
        
        -- if the percentage done changed, display the new value
        IF (l_job_status.Percent_Done != l_percentage_done) THEN
            
            DBMS_OUTPUT.Put_Line
            (
                '*** Job percent done = ' || TO_CHAR(l_job_status.Percent_Done)
            );
            
            l_percentage_done := l_job_status.Percent_Done;
            
        END IF;
        
        -- display any work-in-progress (WIP) or error messages received from the job
        IF
        (
            BITAND(l_status.Mask, DBMS_DATAPUMP.KU$_Status_WIP) != 0
        ) THEN
            
            l_log_entry := l_status.WIP;
            
        ELSE
            
            IF
            (
                BITAND(l_status.Mask, DBMS_DATAPUMP.KU$_Status_Job_Error) != 0
            ) THEN
                
                l_log_entry := l_status.Error;
                
            ELSE
                
                l_log_entry := NULL;
                
            END IF;
            
        END IF;
            
        IF l_log_entry IS NOT NULL THEN
            
            l_loop_index := l_log_entry.FIRST;
            
            WHILE l_loop_index IS NOT NULL LOOP
                
                DBMS_OUTPUT.Put_Line
                (
                    l_log_entry(l_loop_index).LogText
                );
                
                l_loop_index := l_log_entry.NEXT(l_loop_index);
                
            END LOOP;
            
        END IF;
        
    END LOOP;

    -- indicate that the job finished and detach from it
    DBMS_OUTPUT.Put_Line('Job has completed');
    DBMS_OUTPUT.Put_Line('Final job state: ' || l_job_state);
    
    DBMS_DATAPUMP.Detach(l_datapump_handle);
    
    FOR C IN
    (
        SELECT SUBSTR
        (
            File_Name,
            (
                INSTR(File_Name, '/', -1, 1) + 1
            ),
            LENGTH(File_Name)
        ) AS FileName
        FROM DBA_DATA_FILES
        WHERE TableSpace_Name = l_tablespace_name
    ) LOOP
        
        SYS.FCopy_Binary
        (
            'RD_DATAFILES',
            C.FileName,
            l_directory,
            C.FileName
        );
        
    END LOOP;
    
    EXECUTE IMMEDIATE('ALTER TABLESPACE ' || l_tablespace_name || ' READ WRITE');
    
    EXECUTE IMMEDIATE('DROP DIRECTORY ' || l_directory);
    
EXCEPTION
WHEN OTHERS THEN
    
    DBMS_DATAPUMP.Stop_Job(l_datapump_handle);
    
END;
/

/*
--run
SET SERVEROUTPUT ON;

BEGIN

    BACKUP_TABLESPACE('RD');

END;
/
*/