CREATE OR REPLACE
FUNCTION GET_DDL
(
    gObject_Name IN VARCHAR2,
    gObject_Type IN VARCHAR2 DEFAULT 'TABLE'
)
RETURN CLOB
AS
    
    vObject_Name USER_OBJECTS.Object_Name%TYPE := ORACLE_NAME(gObject_Name);
    vObject_Type USER_OBJECTS.Object_Type%TYPE := ORACLE_NAME(gObject_Type);
    cCLOB CLOB;
    
BEGIN
    
    DBMS_LOB.CreateTemporary
    (
        lob_loc => cCLOB,
        cache => TRUE,
        dur => DBMS_LOB.Call
    );
    
    DBMS_LOB.Open(cCLOB, DBMS_LOB.LOB_ReadWrite);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS', FALSE);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', TRUE);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'REF_CONSTRAINTS', FALSE);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'SEGMENT_ATTRIBUTES', FALSE);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'SIZE_BYTE_KEYWORD', TRUE);
        
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE);
    
    DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', FALSE);
    --This is overridden by SEGMENT_ATTRIBUTES -> FALSE
    --DBMS_METADATA.Set_Transform_Param(DBMS_METADATA.SESSION_TRANSFORM, 'TABLESPACE', FALSE);
    
    cCLOB := DBMS_METADATA.Get_DDL(vObject_Type, vObject_Name);
    
    IF vObject_Type = 'TABLE' THEN
        
        
        BEGIN
            
            cCLOB := cCLOB || DBMS_METADATA.Get_Dependent_DDL('COMMENT', vObject_Name);
            
        EXCEPTION
        WHEN OTHERS THEN
            --specified object of type COMMENT not found
            IF SQLCode = -31608 THEN
                
                NULL;
                
            END IF;
            
        END;
        
        
        FOR C IN
        (
            SELECT Index_Name
            FROM USER_INDEXES
            WHERE Table_Name = vObject_Name
            AND Generated = 'N'
        ) LOOP
            
            cCLOB := cCLOB || GET_DDL(C.Index_Name, 'INDEX');
            
        END LOOP;
        
        
        BEGIN
            
            cCLOB := cCLOB || DBMS_METADATA.Get_Dependent_DDL('CONSTRAINT', vObject_Name);
            
        EXCEPTION
        WHEN OTHERS THEN
            --specified object of type CONSTRAINT not found
            IF SQLCode = -31608 THEN
                
                NULL;
                
            END IF;
            
        END;
        
        
        BEGIN
            
            cCLOB := cCLOB || DBMS_METADATA.Get_Dependent_DDL('REF_CONSTRAINT', vObject_Name);
            
        EXCEPTION
        WHEN OTHERS THEN
            --specified object of type REF_CONSTRAINT not found
            IF SQLCode = -31608 THEN
                
                NULL;
                
            END IF;
            
        END;
        
        
    END IF;
    
    RETURN REGEXP_REPLACE(cCLOB, '"' || USER || '".', '');
    
END;
/

/*
--test
SELECT GET_DDL('DBMS')
FROM DUAL;

SET SERVEROUTPUT ON;
    
BEGIN
    
    DBMS_OUTPUT.Enable(1000000);
    
    FOR C IN
    (
        SELECT Table_Name
        FROM USER_TABLES
        --WHERE Table_Name = 'ACCOUNTINGPERIOD'
        ORDER BY Table_Name
    ) LOOP
        
        DBMS_OUTPUT.Put_Line(GET_DDL(C.Table_Name));
        
    END LOOP;
    
END;
/
*/