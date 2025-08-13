-- =====================================================
-- Snowflake Procedure: Apply Table Policies
-- Description: Applies row access policies and column masking policies 
--              based on configuration from DL_CHRS_TABLE_POLICY_MAPPING table
-- =====================================================

CREATE OR REPLACE PROCEDURE DBCSUDL.CHRS.APPLY_TABLE_POLICIES()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- Variables for cursor processing
    policy_cursor CURSOR FOR 
        SELECT 
            PRIORITY,
            TABLENAME,
            COLUMNNAME,
            DIRECTTABLE,
            INDIRECTTABLE,
            INDIRECTTABLECOLUMN,
            ASSIGNEDPOLICY,
            COMMENTS
        FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING
        ORDER BY PRIORITY;
    
    -- Variables to hold cursor values
    v_priority VARCHAR(50);
    v_tablename VARCHAR(100);
    v_columnname VARCHAR(100);
    v_directtable VARCHAR(10);
    v_indirecttable VARCHAR(100);
    v_indirecttablecolumn VARCHAR(100);
    v_assignedpolicy VARCHAR(100);
    v_comments VARCHAR(255);
    
    -- Control variables
    v_sql_statement STRING;
    v_result_message STRING := '';
    v_error_message STRING := '';
    v_processed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    
BEGIN
    -- Initialize result message
    v_result_message := 'Starting policy application process...\n';
    
    -- Open cursor and process each policy mapping
    FOR record IN policy_cursor DO
        BEGIN
            -- Extract values from cursor
            v_priority := record.PRIORITY;
            v_tablename := record.TABLENAME;
            v_columnname := record.COLUMNNAME;
            v_directtable := record.DIRECTTABLE;
            v_indirecttable := record.INDIRECTTABLE;
            v_indirecttablecolumn := record.INDIRECTTABLECOLUMN;
            v_assignedpolicy := record.ASSIGNEDPOLICY;
            v_comments := record.COMMENTS;
            
            -- Determine policy type and build appropriate SQL
            IF v_columnname IS NOT NULL AND v_columnname != '' THEN
                -- Column-level masking policy
                v_sql_statement := 'ALTER TABLE ' || v_tablename || 
                                 ' MODIFY COLUMN ' || v_columnname || 
                                 ' SET MASKING POLICY ' || v_assignedpolicy;
                                 
                v_result_message := v_result_message || 
                    'Applying masking policy ' || v_assignedpolicy || 
                    ' to column ' || v_columnname || ' in table ' || v_tablename || '\n';
                    
            ELSE
                -- Table-level row access policy
                IF v_indirecttablecolumn IS NOT NULL AND v_indirecttablecolumn != '' THEN
                    -- Row access policy with ON clause for specific column(s)
                    v_sql_statement := 'ALTER TABLE ' || v_tablename || 
                                     ' ADD ROW ACCESS POLICY ' || v_assignedpolicy ||
                                     ' ON (' || v_indirecttablecolumn || ')';
                                     
                    v_result_message := v_result_message || 
                        'Applying row access policy ' || v_assignedpolicy || 
                        ' on column ' || v_indirecttablecolumn || 
                        ' in table ' || v_tablename || '\n';
                else
                    -- Standard row access policy without ON clause
                    v_sql_statement := 'ALTER TABLE ' || v_tablename || 
                                     ' ADD ROW ACCESS POLICY ' || v_assignedpolicy;
                                     
                    v_result_message := v_result_message || 
                        'Applying row access policy ' || v_assignedpolicy || 
                        ' to table ' || v_tablename || '\n';
                END IF;
            END IF;
            
            -- Execute the policy application
            EXECUTE IMMEDIATE v_sql_statement;
            
            -- Increment success counter
            v_processed_count := v_processed_count + 1;
            
            -- Log successful application
            v_result_message := v_result_message || 
                'SUCCESS: Applied policy with priority ' || v_priority || '\n';
                
        EXCEPTION
            WHEN OTHER THEN
                -- Handle errors gracefully
                v_error_count := v_error_count + 1;
                v_error_message := v_error_message || 
                    'ERROR applying policy to ' || v_tablename || 
                    CASE WHEN v_columnname IS NOT NULL THEN '.' || v_columnname ELSE '' END ||
                    ': ' || SQLERRM || '\n';
                    
                -- Continue processing other policies
                CONTINUE;
        END;
    END FOR;
    
    -- Build final result message
    v_result_message := v_result_message || 
        '\n=== SUMMARY ===\n' ||
        'Total policies processed successfully: ' || v_processed_count || '\n' ||
        'Total errors encountered: ' || v_error_count || '\n';
        
    IF v_error_count > 0 THEN
        v_result_message := v_result_message || '\nERRORS:\n' || v_error_message;
    END IF;
    
    RETURN v_result_message;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'FATAL ERROR in APPLY_TABLE_POLICIES procedure: ' || SQLERRM;
END;
$$;

-- =====================================================
-- Helper Procedure: Validate Policy Configuration
-- Description: Validates the policy mapping configuration
--              before applying policies
-- =====================================================

CREATE OR REPLACE PROCEDURE DBCSUDL.CHRS.VALIDATE_POLICY_CONFIGURATION()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_validation_result STRING := '';
    v_error_count INTEGER := 0;
    v_warning_count INTEGER := 0;
    
    -- Cursor for validation checks
    validation_cursor CURSOR FOR 
        SELECT 
            PRIORITY,
            TABLENAME,
            COLUMNNAME,
            ASSIGNEDPOLICY,
            CASE 
                WHEN TABLENAME IS NULL OR TRIM(TABLENAME) = '' THEN 'ERROR: Table name is required'
                WHEN ASSIGNEDPOLICY IS NULL OR TRIM(ASSIGNEDPOLICY) = '' THEN 'ERROR: Assigned policy is required'
                WHEN PRIORITY IS NULL OR TRIM(PRIORITY) = '' THEN 'WARNING: Priority is recommended'
                ELSE 'VALID'
            END AS VALIDATION_STATUS
        FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING;
        
BEGIN
    v_validation_result := 'Policy Configuration Validation Report\n';
    v_validation_result := v_validation_result || '==========================================\n\n';
    
    FOR record IN validation_cursor DO
        IF record.VALIDATION_STATUS LIKE 'ERROR:%' THEN
            v_error_count := v_error_count + 1;
            v_validation_result := v_validation_result || 
                'ERROR - Table: ' || COALESCE(record.TABLENAME, 'NULL') || 
                ', Policy: ' || COALESCE(record.ASSIGNEDPOLICY, 'NULL') || 
                ' - ' || record.VALIDATION_STATUS || '\n';
                
        ELSIF record.VALIDATION_STATUS LIKE 'WARNING:%' THEN
            v_warning_count := v_warning_count + 1;
            v_validation_result := v_validation_result || 
                'WARNING - Table: ' || record.TABLENAME || 
                ', Policy: ' || record.ASSIGNEDPOLICY || 
                ' - ' || record.VALIDATION_STATUS || '\n';
        END IF;
    END FOR;
    
    -- Summary
    v_validation_result := v_validation_result || 
        '\nValidation Summary:\n' ||
        'Errors: ' || v_error_count || '\n' ||
        'Warnings: ' || v_warning_count || '\n';
        
    IF v_error_count = 0 THEN
        v_validation_result := v_validation_result || 
            '\n✅ Configuration is valid and ready for policy application.\n';
    ELSE
        v_validation_result := v_validation_result || 
            '\n❌ Configuration has errors that must be fixed before applying policies.\n';
    END IF;
    
    RETURN v_validation_result;
END;
$$;

-- =====================================================
-- Helper Procedure: Remove All Applied Policies
-- Description: Removes all policies applied by the configuration
--              (useful for rollback scenarios)
-- =====================================================

CREATE OR REPLACE PROCEDURE DBCSUDL.CHRS.REMOVE_APPLIED_POLICIES()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    -- Variables for cursor processing
    removal_cursor CURSOR FOR 
        SELECT DISTINCT
            TABLENAME,
            COLUMNNAME,
            ASSIGNEDPOLICY,
            INDIRECTTABLECOLUMN
        FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING
        WHERE ASSIGNEDPOLICY IS NOT NULL;
    
    v_sql_statement STRING;
    v_result_message STRING := '';
    v_removed_count INTEGER := 0;
    v_error_count INTEGER := 0;
    
BEGIN
    v_result_message := 'Starting policy removal process...\n';
    
    FOR record IN removal_cursor DO
        BEGIN
            IF record.COLUMNNAME IS NOT NULL AND record.COLUMNNAME != '' THEN
                -- Remove column masking policy
                v_sql_statement := 'ALTER TABLE ' || record.TABLENAME || 
                                 ' MODIFY COLUMN ' || record.COLUMNNAME || 
                                 ' UNSET MASKING POLICY';
            ELSE
                -- Remove row access policy
                v_sql_statement := 'ALTER TABLE ' || record.TABLENAME || 
                                 ' DROP ROW ACCESS POLICY ' || record.ASSIGNEDPOLICY;
            END IF;
            
            EXECUTE IMMEDIATE v_sql_statement;
            v_removed_count := v_removed_count + 1;
            
            v_result_message := v_result_message || 
                'Removed policy from ' || record.TABLENAME || 
                CASE WHEN record.COLUMNNAME IS NOT NULL THEN '.' || record.COLUMNNAME ELSE '' END || '\n';
                
        EXCEPTION
            WHEN OTHER THEN
                v_error_count := v_error_count + 1;
                v_result_message := v_result_message || 
                    'ERROR removing policy from ' || record.TABLENAME || 
                    CASE WHEN record.COLUMNNAME IS NOT NULL THEN '.' || record.COLUMNNAME ELSE '' END ||
                    ': ' || SQLERRM || '\n';
        END;
    END FOR;
    
    v_result_message := v_result_message || 
        '\nRemoval Summary:\n' ||
        'Policies removed: ' || v_removed_count || '\n' ||
        'Errors: ' || v_error_count || '\n';
        
    RETURN v_result_message;
END;
$$;

-- =====================================================
-- Usage Examples and Documentation
-- =====================================================

/*
USAGE EXAMPLES:

1. Validate configuration before applying policies:
   CALL DBCSUDL.CHRS.VALIDATE_POLICY_CONFIGURATION();

2. Apply all policies from configuration table:
   CALL DBCSUDL.CHRS.APPLY_TABLE_POLICIES();

3. Remove all applied policies (rollback):
   CALL DBCSUDL.CHRS.REMOVE_APPLIED_POLICIES();

CONFIGURATION TABLE STRUCTURE:
- PRIORITY: Processing order (lower numbers processed first)
- TABLENAME: Fully qualified table name (database.schema.table)
- COLUMNNAME: Column name for masking policies (NULL for row access policies)
- DIRECTTABLE: Flag indicating if this is a direct table policy
- INDIRECTTABLE: Reference table for indirect policies
- INDIRECTTABLECOLUMN: Column in reference table for indirect policies
- ASSIGNEDPOLICY: Name of the policy to apply
- COMMENTS: Description or notes about the policy

POLICY TYPES SUPPORTED:
1. Row Access Policies: Applied when COLUMNNAME is NULL/empty
   a. Standard Row Access Policies: Applied to entire table
   b. Column-specific Row Access Policies: Applied with ON (column) clause when INDIRECTTABLECOLUMN is specified
2. Column Masking Policies: Applied when COLUMNNAME is specified

ERROR HANDLING:
- Individual policy application errors don't stop the entire process
- Detailed error messages are returned in the result
- Summary statistics provided at the end
*/
