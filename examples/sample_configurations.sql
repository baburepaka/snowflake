-- =====================================================
-- Sample Configurations for User Management
-- =====================================================
-- This file contains example data for the configuration tables

-- =====================================================
-- 1. Sample Role Configurations
-- =====================================================

-- Insert sample roles with hierarchy
INSERT INTO ROLE_CONFIG (ROLE_NAME, PARENT_ROLE, ROLE_TYPE, DESCRIPTION, AUTO_GRANT) VALUES
('DATA_READER', NULL, 'FUNCTIONAL', 'Basic read access to data', TRUE),
('DATA_WRITER', 'DATA_READER', 'FUNCTIONAL', 'Read and write access to data', FALSE),
('DATA_ANALYST', 'DATA_READER', 'FUNCTIONAL', 'Analyst role with reporting capabilities', FALSE),
('DATA_SCIENTIST', 'DATA_ANALYST', 'FUNCTIONAL', 'Advanced analytics and ML capabilities', FALSE),
('DATA_ENGINEER', 'DATA_WRITER', 'FUNCTIONAL', 'ETL and pipeline development', FALSE),
('ADMIN', NULL, 'ACCESS', 'Administrative privileges', FALSE),
('DEVELOPER', 'DATA_WRITER', 'FUNCTIONAL', 'Development environment access', FALSE),
('BUSINESS_USER', 'DATA_READER', 'FUNCTIONAL', 'Business user with dashboard access', FALSE);

-- =====================================================
-- 2. Sample User Configurations
-- =====================================================

-- Insert sample users
INSERT INTO USER_CONFIG (
    USER_NAME, EMAIL, FIRST_NAME, LAST_NAME, 
    DEFAULT_WAREHOUSE, DEFAULT_NAMESPACE, 
    MUST_CHANGE_PASSWORD, COMMENT
) VALUES
('JOHN_DOE', 'john.doe@company.com', 'John', 'Doe', 
 'COMPUTE_WH', 'ANALYTICS_DB.PUBLIC', TRUE, 'Data Analyst'),
('JANE_SMITH', 'jane.smith@company.com', 'Jane', 'Smith', 
 'COMPUTE_WH', 'ANALYTICS_DB.PUBLIC', TRUE, 'Data Scientist'),
('BOB_JOHNSON', 'bob.johnson@company.com', 'Bob', 'Johnson', 
 'ETL_WH', 'ETL_DB.STAGING', TRUE, 'Data Engineer'),
('ALICE_BROWN', 'alice.brown@company.com', 'Alice', 'Brown', 
 'COMPUTE_WH', 'ANALYTICS_DB.PUBLIC', TRUE, 'Business Analyst'),
('MIKE_WILSON', 'mike.wilson@company.com', 'Mike', 'Wilson', 
 'ADMIN_WH', 'ADMIN_DB.PUBLIC', TRUE, 'System Administrator');

-- =====================================================
-- 3. Sample User-Role Mappings
-- =====================================================

-- Assign roles to users
INSERT INTO USER_ROLE_CONFIG (USER_NAME, ROLE_NAME, IS_DEFAULT_ROLE) VALUES
-- John Doe - Data Analyst
('JOHN_DOE', 'DATA_ANALYST', TRUE),
('JOHN_DOE', 'DATA_READER', FALSE),

-- Jane Smith - Data Scientist
('JANE_SMITH', 'DATA_SCIENTIST', TRUE),
('JANE_SMITH', 'DATA_ANALYST', FALSE),
('JANE_SMITH', 'DATA_READER', FALSE),

-- Bob Johnson - Data Engineer
('BOB_JOHNSON', 'DATA_ENGINEER', TRUE),
('BOB_JOHNSON', 'DATA_WRITER', FALSE),
('BOB_JOHNSON', 'DATA_READER', FALSE),

-- Alice Brown - Business User
('ALICE_BROWN', 'BUSINESS_USER', TRUE),
('ALICE_BROWN', 'DATA_READER', FALSE),

-- Mike Wilson - Administrator
('MIKE_WILSON', 'ADMIN', TRUE),
('MIKE_WILSON', 'DATA_ENGINEER', FALSE),
('MIKE_WILSON', 'DATA_SCIENTIST', FALSE);

-- =====================================================
-- 4. Example Usage Commands
-- =====================================================

/*
-- Create a single user with roles
CALL CREATE_USER_WITH_ROLES(
    'NEW_USER', 
    'new.user@company.com', 
    'New', 
    'User', 
    'COMPUTE_WH', 
    'ANALYTICS_DB.PUBLIC',
    NULL, -- Password (NULL for SSO)
    TRUE, -- Must change password
    'New team member'
);

-- Create all users from configuration
CALL CREATE_USERS_FROM_CONFIG();

-- Grant additional role to existing user
CALL GRANT_ROLE_TO_USER('JOHN_DOE', 'DEVELOPER', FALSE);

-- Revoke role from user
CALL REVOKE_ROLE_FROM_USER('JOHN_DOE', 'DEVELOPER');

-- Get user's roles
CALL GET_USER_ROLES('JOHN_DOE');

-- Disable/Enable user
CALL DISABLE_USER('JOHN_DOE');
CALL ENABLE_USER('JOHN_DOE');

-- Query user configurations
SELECT * FROM USER_CONFIG WHERE DISABLED = FALSE;

-- Query role assignments
SELECT 
    u.USER_NAME,
    u.EMAIL,
    u.FIRST_NAME,
    u.LAST_NAME,
    r.ROLE_NAME,
    r.IS_DEFAULT_ROLE,
    rc.ROLE_TYPE,
    rc.DESCRIPTION
FROM USER_CONFIG u
JOIN USER_ROLE_CONFIG r ON u.USER_NAME = r.USER_NAME
JOIN ROLE_CONFIG rc ON r.ROLE_NAME = rc.ROLE_NAME
WHERE u.DISABLED = FALSE
ORDER BY u.USER_NAME, r.IS_DEFAULT_ROLE DESC;
*/

