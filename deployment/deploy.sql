-- =====================================================
-- Snowflake User Management System Deployment Script
-- =====================================================
-- Run this script to deploy the complete user management system

-- Set context (modify as needed for your environment)
USE ROLE SECURITYADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE YOUR_DATABASE;
USE SCHEMA PUBLIC;

-- =====================================================
-- 1. Create Configuration Tables
-- =====================================================

-- Table to store user configurations
CREATE OR REPLACE TABLE USER_CONFIG (
    USER_NAME VARCHAR(255) NOT NULL,
    EMAIL VARCHAR(255),
    FIRST_NAME VARCHAR(255),
    LAST_NAME VARCHAR(255),
    DEFAULT_WAREHOUSE VARCHAR(255),
    DEFAULT_NAMESPACE VARCHAR(255),
    PASSWORD VARCHAR(255), -- Optional, can be NULL for SSO users
    MUST_CHANGE_PASSWORD BOOLEAN DEFAULT TRUE,
    DISABLED BOOLEAN DEFAULT FALSE,
    COMMENT VARCHAR(1000),
    CREATED_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_NAME)
);

-- Table to store role configurations and mappings
CREATE OR REPLACE TABLE USER_ROLE_CONFIG (
    USER_NAME VARCHAR(255) NOT NULL,
    ROLE_NAME VARCHAR(255) NOT NULL,
    IS_DEFAULT_ROLE BOOLEAN DEFAULT FALSE,
    GRANTED_BY VARCHAR(255) DEFAULT CURRENT_USER(),
    GRANT_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (USER_NAME, ROLE_NAME)
);

-- Table to store role hierarchy and permissions
CREATE OR REPLACE TABLE ROLE_CONFIG (
    ROLE_NAME VARCHAR(255) NOT NULL,
    PARENT_ROLE VARCHAR(255),
    ROLE_TYPE VARCHAR(50), -- 'FUNCTIONAL', 'ACCESS', 'CUSTOM'
    DESCRIPTION VARCHAR(1000),
    AUTO_GRANT BOOLEAN DEFAULT FALSE, -- Automatically grant to new users
    CREATED_DATE TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ROLE_NAME)
);

-- =====================================================
-- 2. Create Stored Procedures
-- =====================================================

-- Main user creation procedure
CREATE OR REPLACE PROCEDURE CREATE_USER_WITH_ROLES(
    P_USER_NAME VARCHAR(255),
    P_EMAIL VARCHAR(255) DEFAULT NULL,
    P_FIRST_NAME VARCHAR(255) DEFAULT NULL,
    P_LAST_NAME VARCHAR(255) DEFAULT NULL,
    P_DEFAULT_WAREHOUSE VARCHAR(255) DEFAULT NULL,
    P_DEFAULT_NAMESPACE VARCHAR(255) DEFAULT NULL,
    P_PASSWORD VARCHAR(255) DEFAULT NULL,
    P_MUST_CHANGE_PASSWORD BOOLEAN DEFAULT TRUE,
    P_COMMENT VARCHAR(1000) DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    user_exists BOOLEAN DEFAULT FALSE;
    sql_command STRING;
    role_cursor CURSOR FOR 
        SELECT ROLE_NAME, IS_DEFAULT_ROLE 
        FROM USER_ROLE_CONFIG 
        WHERE USER_NAME = P_USER_NAME;
    auto_role_cursor CURSOR FOR 
        SELECT ROLE_NAME 
        FROM ROLE_CONFIG 
        WHERE AUTO_GRANT = TRUE;
    result_message STRING DEFAULT '';
    role_name STRING;
    is_default BOOLEAN;
BEGIN
    -- Check if user already exists
    SELECT COUNT(*) > 0 INTO user_exists 
    FROM INFORMATION_SCHEMA.USERS 
    WHERE USER_NAME = UPPER(P_USER_NAME);
    
    IF (user_exists) THEN
        result_message := 'User ' || P_USER_NAME || ' already exists. Updating role assignments only.';
    ELSE
        -- Build CREATE USER command
        sql_command := 'CREATE USER ' || P_USER_NAME;
        
        IF (P_PASSWORD IS NOT NULL) THEN
            sql_command := sql_command || ' PASSWORD = ''' || P_PASSWORD || '''';
        END IF;
        
        IF (P_EMAIL IS NOT NULL) THEN
            sql_command := sql_command || ' EMAIL = ''' || P_EMAIL || '''';
        END IF;
        
        IF (P_FIRST_NAME IS NOT NULL) THEN
            sql_command := sql_command || ' FIRST_NAME = ''' || P_FIRST_NAME || '''';
        END IF;
        
        IF (P_LAST_NAME IS NOT NULL) THEN
            sql_command := sql_command || ' LAST_NAME = ''' || P_LAST_NAME || '''';
        END IF;
        
        IF (P_DEFAULT_WAREHOUSE IS NOT NULL) THEN
            sql_command := sql_command || ' DEFAULT_WAREHOUSE = ' || P_DEFAULT_WAREHOUSE;
        END IF;
        
        IF (P_DEFAULT_NAMESPACE IS NOT NULL) THEN
            sql_command := sql_command || ' DEFAULT_NAMESPACE = ''' || P_DEFAULT_NAMESPACE || '''';
        END IF;
        
        sql_command := sql_command || ' MUST_CHANGE_PASSWORD = ' || P_MUST_CHANGE_PASSWORD::STRING;
        
        IF (P_COMMENT IS NOT NULL) THEN
            sql_command := sql_command || ' COMMENT = ''' || P_COMMENT || '''';
        END IF;
        
        -- Execute user creation
        EXECUTE IMMEDIATE sql_command;
        result_message := 'User ' || P_USER_NAME || ' created successfully. ';
    END IF;
    
    -- Grant roles from USER_ROLE_CONFIG
    FOR role_record IN role_cursor DO
        role_name := role_record.ROLE_NAME;
        is_default := role_record.IS_DEFAULT_ROLE;
        
        -- Grant the role
        sql_command := 'GRANT ROLE ' || role_name || ' TO USER ' || P_USER_NAME;
        EXECUTE IMMEDIATE sql_command;
        
        -- Set as default role if specified
        IF (is_default) THEN
            sql_command := 'ALTER USER ' || P_USER_NAME || ' SET DEFAULT_ROLE = ' || role_name;
            EXECUTE IMMEDIATE sql_command;
        END IF;
        
        result_message := result_message || 'Granted role ' || role_name || 
                         CASE WHEN is_default THEN ' (default)' ELSE '' END || '. ';
    END FOR;
    
    -- Grant auto-grant roles
    FOR auto_role_record IN auto_role_cursor DO
        role_name := auto_role_record.ROLE_NAME;
        
        -- Check if role is not already granted via USER_ROLE_CONFIG
        IF NOT EXISTS (
            SELECT 1 FROM USER_ROLE_CONFIG 
            WHERE USER_NAME = P_USER_NAME AND ROLE_NAME = role_name
        ) THEN
            sql_command := 'GRANT ROLE ' || role_name || ' TO USER ' || P_USER_NAME;
            EXECUTE IMMEDIATE sql_command;
            result_message := result_message || 'Auto-granted role ' || role_name || '. ';
        END IF;
    END FOR;
    
    -- Insert/Update user configuration
    MERGE INTO USER_CONFIG AS target
    USING (
        SELECT 
            P_USER_NAME AS USER_NAME,
            P_EMAIL AS EMAIL,
            P_FIRST_NAME AS FIRST_NAME,
            P_LAST_NAME AS LAST_NAME,
            P_DEFAULT_WAREHOUSE AS DEFAULT_WAREHOUSE,
            P_DEFAULT_NAMESPACE AS DEFAULT_NAMESPACE,
            P_PASSWORD AS PASSWORD,
            P_MUST_CHANGE_PASSWORD AS MUST_CHANGE_PASSWORD,
            FALSE AS DISABLED,
            P_COMMENT AS COMMENT,
            CURRENT_TIMESTAMP() AS UPDATED_DATE
    ) AS source ON target.USER_NAME = source.USER_NAME
    WHEN MATCHED THEN
        UPDATE SET
            EMAIL = source.EMAIL,
            FIRST_NAME = source.FIRST_NAME,
            LAST_NAME = source.LAST_NAME,
            DEFAULT_WAREHOUSE = source.DEFAULT_WAREHOUSE,
            DEFAULT_NAMESPACE = source.DEFAULT_NAMESPACE,
            PASSWORD = source.PASSWORD,
            MUST_CHANGE_PASSWORD = source.MUST_CHANGE_PASSWORD,
            COMMENT = source.COMMENT,
            UPDATED_DATE = source.UPDATED_DATE
    WHEN NOT MATCHED THEN
        INSERT (USER_NAME, EMAIL, FIRST_NAME, LAST_NAME, DEFAULT_WAREHOUSE, 
                DEFAULT_NAMESPACE, PASSWORD, MUST_CHANGE_PASSWORD, DISABLED, COMMENT)
        VALUES (source.USER_NAME, source.EMAIL, source.FIRST_NAME, source.LAST_NAME,
                source.DEFAULT_WAREHOUSE, source.DEFAULT_NAMESPACE, source.PASSWORD,
                source.MUST_CHANGE_PASSWORD, source.DISABLED, source.COMMENT);
    
    RETURN result_message || 'User configuration updated.';
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error creating user: ' || SQLERRM;
END;
$$;

-- Bulk user creation procedure
CREATE OR REPLACE PROCEDURE CREATE_USERS_FROM_CONFIG()
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    user_cursor CURSOR FOR 
        SELECT USER_NAME, EMAIL, FIRST_NAME, LAST_NAME, 
               DEFAULT_WAREHOUSE, DEFAULT_NAMESPACE, PASSWORD, 
               MUST_CHANGE_PASSWORD, COMMENT
        FROM USER_CONFIG 
        WHERE DISABLED = FALSE;
    result_message STRING DEFAULT '';
    user_result STRING;
BEGIN
    FOR user_record IN user_cursor DO
        CALL CREATE_USER_WITH_ROLES(
            user_record.USER_NAME,
            user_record.EMAIL,
            user_record.FIRST_NAME,
            user_record.LAST_NAME,
            user_record.DEFAULT_WAREHOUSE,
            user_record.DEFAULT_NAMESPACE,
            user_record.PASSWORD,
            user_record.MUST_CHANGE_PASSWORD,
            user_record.COMMENT
        ) INTO user_result;
        
        result_message := result_message || user_result || '\n';
    END FOR;
    
    RETURN result_message;
END;
$$;

-- Role management procedures
CREATE OR REPLACE PROCEDURE GRANT_ROLE_TO_USER(
    P_USER_NAME VARCHAR(255),
    P_ROLE_NAME VARCHAR(255),
    P_IS_DEFAULT BOOLEAN DEFAULT FALSE
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    sql_command STRING;
BEGIN
    -- Grant the role
    sql_command := 'GRANT ROLE ' || P_ROLE_NAME || ' TO USER ' || P_USER_NAME;
    EXECUTE IMMEDIATE sql_command;
    
    -- Set as default if specified
    IF (P_IS_DEFAULT) THEN
        sql_command := 'ALTER USER ' || P_USER_NAME || ' SET DEFAULT_ROLE = ' || P_ROLE_NAME;
        EXECUTE IMMEDIATE sql_command;
    END IF;
    
    -- Update configuration
    INSERT INTO USER_ROLE_CONFIG (USER_NAME, ROLE_NAME, IS_DEFAULT_ROLE)
    VALUES (P_USER_NAME, P_ROLE_NAME, P_IS_DEFAULT)
    ON CONFLICT (USER_NAME, ROLE_NAME) DO UPDATE SET
        IS_DEFAULT_ROLE = P_IS_DEFAULT,
        GRANT_DATE = CURRENT_TIMESTAMP();
    
    RETURN 'Role ' || P_ROLE_NAME || ' granted to user ' || P_USER_NAME || 
           CASE WHEN P_IS_DEFAULT THEN ' (set as default)' ELSE '' END;
           
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error granting role: ' || SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE REVOKE_ROLE_FROM_USER(
    P_USER_NAME VARCHAR(255),
    P_ROLE_NAME VARCHAR(255)
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    sql_command STRING;
BEGIN
    -- Revoke the role
    sql_command := 'REVOKE ROLE ' || P_ROLE_NAME || ' FROM USER ' || P_USER_NAME;
    EXECUTE IMMEDIATE sql_command;
    
    -- Remove from configuration
    DELETE FROM USER_ROLE_CONFIG 
    WHERE USER_NAME = P_USER_NAME AND ROLE_NAME = P_ROLE_NAME;
    
    RETURN 'Role ' || P_ROLE_NAME || ' revoked from user ' || P_USER_NAME;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error revoking role: ' || SQLERRM;
END;
$$;

-- Utility procedures
CREATE OR REPLACE PROCEDURE GET_USER_ROLES(P_USER_NAME VARCHAR(255))
RETURNS TABLE (ROLE_NAME VARCHAR(255), IS_DEFAULT BOOLEAN, GRANT_DATE TIMESTAMP_NTZ)
LANGUAGE SQL
AS
$$
    SELECT ROLE_NAME, IS_DEFAULT_ROLE, GRANT_DATE
    FROM USER_ROLE_CONFIG
    WHERE USER_NAME = P_USER_NAME
    ORDER BY IS_DEFAULT_ROLE DESC, ROLE_NAME;
$$;

CREATE OR REPLACE PROCEDURE DISABLE_USER(P_USER_NAME VARCHAR(255))
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    sql_command STRING;
BEGIN
    -- Disable user in Snowflake
    sql_command := 'ALTER USER ' || P_USER_NAME || ' SET DISABLED = TRUE';
    EXECUTE IMMEDIATE sql_command;
    
    -- Update configuration
    UPDATE USER_CONFIG 
    SET DISABLED = TRUE, UPDATED_DATE = CURRENT_TIMESTAMP()
    WHERE USER_NAME = P_USER_NAME;
    
    RETURN 'User ' || P_USER_NAME || ' has been disabled';
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error disabling user: ' || SQLERRM;
END;
$$;

CREATE OR REPLACE PROCEDURE ENABLE_USER(P_USER_NAME VARCHAR(255))
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    sql_command STRING;
BEGIN
    -- Enable user in Snowflake
    sql_command := 'ALTER USER ' || P_USER_NAME || ' SET DISABLED = FALSE';
    EXECUTE IMMEDIATE sql_command;
    
    -- Update configuration
    UPDATE USER_CONFIG 
    SET DISABLED = FALSE, UPDATED_DATE = CURRENT_TIMESTAMP()
    WHERE USER_NAME = P_USER_NAME;
    
    RETURN 'User ' || P_USER_NAME || ' has been enabled';
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error enabling user: ' || SQLERRM;
END;
$$;

-- =====================================================
-- 3. Create Views for Easy Querying
-- =====================================================

CREATE OR REPLACE VIEW USER_ROLE_SUMMARY AS
SELECT 
    u.USER_NAME,
    u.EMAIL,
    u.FIRST_NAME,
    u.LAST_NAME,
    u.DEFAULT_WAREHOUSE,
    u.DEFAULT_NAMESPACE,
    u.DISABLED,
    r.ROLE_NAME,
    r.IS_DEFAULT_ROLE,
    rc.ROLE_TYPE,
    rc.DESCRIPTION AS ROLE_DESCRIPTION,
    r.GRANT_DATE
FROM USER_CONFIG u
LEFT JOIN USER_ROLE_CONFIG r ON u.USER_NAME = r.USER_NAME
LEFT JOIN ROLE_CONFIG rc ON r.ROLE_NAME = rc.ROLE_NAME
ORDER BY u.USER_NAME, r.IS_DEFAULT_ROLE DESC, r.ROLE_NAME;

CREATE OR REPLACE VIEW ACTIVE_USERS AS
SELECT 
    USER_NAME,
    EMAIL,
    FIRST_NAME,
    LAST_NAME,
    DEFAULT_WAREHOUSE,
    DEFAULT_NAMESPACE,
    CREATED_DATE,
    UPDATED_DATE
FROM USER_CONFIG 
WHERE DISABLED = FALSE;

-- =====================================================
-- 4. Grant Permissions
-- =====================================================

-- Grant usage on procedures to appropriate roles
-- Modify these grants based on your security requirements

GRANT USAGE ON PROCEDURE CREATE_USER_WITH_ROLES(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BOOLEAN, VARCHAR) TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE CREATE_USERS_FROM_CONFIG() TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE GRANT_ROLE_TO_USER(VARCHAR, VARCHAR, BOOLEAN) TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE REVOKE_ROLE_FROM_USER(VARCHAR, VARCHAR) TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE GET_USER_ROLES(VARCHAR) TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE DISABLE_USER(VARCHAR) TO ROLE USERADMIN;
GRANT USAGE ON PROCEDURE ENABLE_USER(VARCHAR) TO ROLE USERADMIN;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE USER_CONFIG TO ROLE USERADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE USER_ROLE_CONFIG TO ROLE USERADMIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE ROLE_CONFIG TO ROLE USERADMIN;

-- Grant view permissions
GRANT SELECT ON VIEW USER_ROLE_SUMMARY TO ROLE USERADMIN;
GRANT SELECT ON VIEW ACTIVE_USERS TO ROLE USERADMIN;

-- =====================================================
-- Deployment Complete
-- =====================================================

SELECT 'Snowflake User Management System deployed successfully!' AS STATUS;

