SET DEFINE OFF;
SET SERVEROUTPUT ON;
SET TIMING ON;

CREATE OR REPLACE
PROCEDURE DROP_FK
(
    gOwner IN VARCHAR2,
    gTable_Name IN VARCHAR2,
    gCLOB_Table IN OUT T_CLOB_TABLE,
    gDebug IN NUMBER DEFAULT 0
)
AUTHID CURRENT_USER
AS
    
    bDebug BOOLEAN := CASE gDebug
        WHEN 1 THEN TRUE
        ELSE FALSE
    END;
    
    sColumn_Expression	VARCHAR2(32767 BYTE) := '';
    sColumnString VARCHAR2(32767 BYTE) := '';
    
    END_PREMATURELY EXCEPTION;
    vError VARCHAR2(255 BYTE);
    
BEGIN
    
    DBMS_OUTPUT.Enable(NULL);
    
    --DBMS_OUTPUT.New_Line();
    --DBMS_OUTPUT.Put_Line('--User: ' || gOwner);
    --DBMS_OUTPUT.Put_Line('--Table name: ' || gTable_Name);
    --DBMS_OUTPUT.New_Line();
    
    FOR W IN
    (
        SELECT Owner AS Index_Owner,
        Index_Name
        FROM ALL_INDEXES
        WHERE Table_Owner = gOwner
        AND Table_Name = gTable_Name
        AND Uniqueness = 'UNIQUE'
    ) LOOP
        
        --DBMS_OUTPUT.Put_Line('--Unique key: ' || W.Index_Owner || '.' || W.Index_Name);
        --DBMS_OUTPUT.New_Line();
        
        FOR X IN
        (
            SELECT UC.Owner,
            UC.Table_Name,
            UC.Constraint_Name,
            UI.Index_Name,
            UC.Delete_Rule,
            UC."DEFERRABLE"
            FROM ALL_CONSTRAINTS UC
            INNER JOIN ALL_INDEXES UI
                ON UC.R_Owner = UI.Owner
                        AND UC.R_Constraint_Name = UI.Index_Name
            WHERE (UC.Table_Name, UC.Constraint_Name) IN
            (
                SELECT Table_Name,
                Constraint_Name
                FROM ALL_CONSTRAINTS
                WHERE R_Owner = W.Index_Owner
                AND Constraint_Type = 'R'
                AND R_Constraint_Name =  W.Index_Name
            )
            AND UC.Constraint_Type = 'R'
            AND UC.R_Owner = W.Index_Owner
            ORDER BY UC.Constraint_Name
        ) LOOP
            
            gCLOB_Table.extend;
            sColumnString := NULL;
            
            gCLOB_Table(gCLOB_Table.Last) := 'ALTER TABLE ' || X.Owner || '.' || X.Table_Name || '
ADD CONSTRAINT ' || X.Constraint_Name || ' FOREIGN KEY
(';
            
            /*DBMS_OUTPUT.Put_Line('ALTER TABLE ' || X.Owner || '.' || X.Table_Name || '
ADD CONSTRAINT ' || X.Constraint_Name || ' FOREIGN KEY
(');*/
            
            FOR Y IN
            (
                SELECT CASE Position
                    WHEN 1 THEN '    '
                    ELSE '  , '
                END AS Prefix,
                Column_Name
                FROM ALL_CONS_COLUMNS
                WHERE Owner = X.Owner
                and Table_Name = X.Table_Name
                AND Constraint_Name = X.Constraint_Name
                ORDER BY Position
            ) LOOP
                
                gCLOB_Table(gCLOB_Table.last) := gCLOB_Table(gCLOB_Table.last) || CHR(10) || Y.Prefix || Y.Column_Name;
                
                --DBMS_OUTPUT.Put_Line(Y.Prefix || Y.Column_Name);
                
            END LOOP;
            
            
            FOR Y IN
            (
                SELECT CASE Column_Position
                    WHEN 1 THEN ''
                    ELSE ', '
                END AS Prefix,
                Column_Position,
                Column_Name
                FROM ALL_IND_COLUMNS
                WHERE Index_Owner = W.index_owner
                AND Index_Name = X.Index_Name
                ORDER BY Column_Position
            ) LOOP
                
                BEGIN
                    
                    SELECT Column_Expression
                    INTO sColumn_Expression
                    FROM ALL_IND_EXPRESSIONS
                    WHERE Index_Owner = W.Index_Owner
                    AND Index_Name = X.Index_Name
                    AND Column_Position = Y.Column_Position;
                    
                    sColumn_Expression := REPLACE(sColumn_Expression, '"', NULL);
                    
                    sColumnString := sColumnString || Y.Prefix || sColumn_Expression;
                    
                EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    
                    sColumnString := sColumnString || Y.Prefix || Y.Column_Name;
                    
                END;
                
            END LOOP; --Y
            
            gCLOB_Table(gCLOB_Table.Last) := gCLOB_Table(gCLOB_Table.Last) || '
) REFERENCES ' || gOwner || '.' || gTable_Name || '(' || sColumnString || ')'
            || CASE
            WHEN TRIM(X.Delete_Rule) = 'NO ACTION' THEN NULL
            ELSE '
ON DELETE ' || TRIM(X.Delete_Rule)
            END || '
            ' || TRIM(X."DEFERRABLE");
            
            /*DBMS_OUTPUT.Put_Line('  ) REFERENCES ' || gOwner || '.' || gTable_Name || '(' || sColumnString || ')
;');
              DBMS_OUTPUT.New_Line();*/
            
            IF bDebug THEN
                
                DBMS_OUTPUT.Put_Line('ALTER TABLE "' || X.Owner || '"."' || X.Table_Name || '" DROP CONSTRAINT "' || X.Constraint_Name || '";');
                DBMS_OUTPUT.New_Line();
                
            ELSE
                
                EXECUTE IMMEDIATE('ALTER TABLE ":1".":2" DROP CONSTRAINT ":3"')
                USING X.Owner, X.Table_Name, X.Constraint_Name;
                
            END IF;
        
        END LOOP; --X
    
    END LOOP; --W
    
EXCEPTION
WHEN END_PREMATURELY THEN
    
    DBMS_OUTPUT.Put_Line('Ended prematurely');
    
WHEN OTHERS THEN
    
    vError := SUBSTRB(SQLERRM, 1, 255);
    DBMS_OUTPUT.Put_Line(vError);
    
END;
/

GRANT EXECUTE ON DROP_FK TO PUBLIC WITH GRANT OPTION;

/*
--test
SET SERVEROUTPUT ON;

DECLARE
    
    gCLOB_Table RD.T_CLOB_TABLE := RD.T_CLOB_TABLE();
    
BEGIN
    
    RD.DROP_FK('RD', 'NAMESPACE', gCLOB_Table, 0);
    
    IF gCLOB_Table.Last != 0 THEN
        
        FOR i IN gCLOB_Table.First..gCLOB_Table.Last LOOP
        
        DBMS_OUTPUT.New_Line();
        DBMS_OUTPUT.Put_Line(gCLOB_Table(i) || ';');
        
        END LOOP;
        
    ELSE
        
        DBMS_OUTPUT.Put_Line('No results');
        
    END IF;
    
END;
/
*/
--NAMESPACE#NAMINGCONVENTION_NAMINGCONVENTION_FK gives ORA-06546: DDL statement is executed in an illegal context