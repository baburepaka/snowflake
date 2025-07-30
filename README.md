# Snowflake User Management System

A comprehensive stored procedure system for managing Snowflake users and role assignments based on configuration tables.

## Overview

This system provides:
- **Automated user creation** with configurable properties
- **Role-based access control** with hierarchical role management
- **Bulk user provisioning** from configuration tables
- **Audit trail** and configuration management
- **Flexible role assignment** with default role support

## Components

### 1. Configuration Tables

- **`USER_CONFIG`**: Stores user definitions and properties
- **`USER_ROLE_CONFIG`**: Maps users to roles with default role settings
- **`ROLE_CONFIG`**: Defines role hierarchy and auto-grant settings

### 2. Core Procedures

- **`CREATE_USER_WITH_ROLES()`**: Creates individual users with role assignments
- **`CREATE_USERS_FROM_CONFIG()`**: Bulk creates users from configuration tables
- **`GRANT_ROLE_TO_USER()`**: Grants roles to existing users
- **`REVOKE_ROLE_FROM_USER()`**: Revokes roles from users
- **`GET_USER_ROLES()`**: Returns user's role assignments
- **`DISABLE_USER()`** / **`ENABLE_USER()`**: User account management

## Quick Start

### 1. Deploy the System

```sql
-- Run the main procedure file
@procedures/user_management.sql

-- Load sample configurations (optional)
@examples/sample_configurations.sql
```

### 2. Configure Users and Roles

```sql
-- Add a role configuration
INSERT INTO ROLE_CONFIG (ROLE_NAME, ROLE_TYPE, DESCRIPTION, AUTO_GRANT) 
VALUES ('DATA_ANALYST', 'FUNCTIONAL', 'Data analysis role', FALSE);

-- Add a user configuration
INSERT INTO USER_CONFIG (
    USER_NAME, EMAIL, FIRST_NAME, LAST_NAME, 
    DEFAULT_WAREHOUSE, DEFAULT_NAMESPACE
) VALUES (
    'JOHN_DOE', 'john.doe@company.com', 'John', 'Doe',
    'COMPUTE_WH', 'ANALYTICS_DB.PUBLIC'
);

-- Map user to role
INSERT INTO USER_ROLE_CONFIG (USER_NAME, ROLE_NAME, IS_DEFAULT_ROLE)
VALUES ('JOHN_DOE', 'DATA_ANALYST', TRUE);
```

### 3. Create Users

```sql
-- Create a single user
CALL CREATE_USER_WITH_ROLES(
    'JOHN_DOE',                    -- User name
    'john.doe@company.com',        -- Email
    'John',                        -- First name
    'Doe',                         -- Last name
    'COMPUTE_WH',                  -- Default warehouse
    'ANALYTICS_DB.PUBLIC',         -- Default namespace
    NULL,                          -- Password (NULL for SSO)
    TRUE,                          -- Must change password
    'Data Analyst'                 -- Comment
);

-- Or create all configured users at once
CALL CREATE_USERS_FROM_CONFIG();
```

## Procedure Reference

### CREATE_USER_WITH_ROLES()

Creates a user with specified properties and assigns roles based on configuration.

**Parameters:**
- `P_USER_NAME` (VARCHAR): User name (required)
- `P_EMAIL` (VARCHAR): Email address
- `P_FIRST_NAME` (VARCHAR): First name
- `P_LAST_NAME` (VARCHAR): Last name
- `P_DEFAULT_WAREHOUSE` (VARCHAR): Default warehouse
- `P_DEFAULT_NAMESPACE` (VARCHAR): Default database.schema
- `P_PASSWORD` (VARCHAR): Password (NULL for SSO users)
- `P_MUST_CHANGE_PASSWORD` (BOOLEAN): Force password change on first login
- `P_COMMENT` (VARCHAR): User description

**Example:**
```sql
CALL CREATE_USER_WITH_ROLES(
    'NEW_USER', 
    'user@company.com', 
    'First', 
    'Last',
    'COMPUTE_WH',
    'DB.SCHEMA',
    'TempPassword123',
    TRUE,
    'New team member'
);
```

### GRANT_ROLE_TO_USER()

Grants a role to an existing user and optionally sets it as default.

**Parameters:**
- `P_USER_NAME` (VARCHAR): Target user name
- `P_ROLE_NAME` (VARCHAR): Role to grant
- `P_IS_DEFAULT` (BOOLEAN): Set as default role

**Example:**
```sql
CALL GRANT_ROLE_TO_USER('JOHN_DOE', 'DATA_SCIENTIST', TRUE);
```

### GET_USER_ROLES()

Returns all roles assigned to a user.

**Example:**
```sql
CALL GET_USER_ROLES('JOHN_DOE');
```

## Configuration Tables Schema

### USER_CONFIG
```sql
USER_NAME VARCHAR(255) PRIMARY KEY
EMAIL VARCHAR(255)
FIRST_NAME VARCHAR(255)
LAST_NAME VARCHAR(255)
DEFAULT_WAREHOUSE VARCHAR(255)
DEFAULT_NAMESPACE VARCHAR(255)
PASSWORD VARCHAR(255)
MUST_CHANGE_PASSWORD BOOLEAN
DISABLED BOOLEAN
COMMENT VARCHAR(1000)
CREATED_DATE TIMESTAMP_NTZ
UPDATED_DATE TIMESTAMP_NTZ
```

### USER_ROLE_CONFIG
```sql
USER_NAME VARCHAR(255)
ROLE_NAME VARCHAR(255)
IS_DEFAULT_ROLE BOOLEAN
GRANTED_BY VARCHAR(255)
GRANT_DATE TIMESTAMP_NTZ
PRIMARY KEY (USER_NAME, ROLE_NAME)
```

### ROLE_CONFIG
```sql
ROLE_NAME VARCHAR(255) PRIMARY KEY
PARENT_ROLE VARCHAR(255)
ROLE_TYPE VARCHAR(50)
DESCRIPTION VARCHAR(1000)
AUTO_GRANT BOOLEAN
CREATED_DATE TIMESTAMP_NTZ
```

## Features

### Role Hierarchy
- Define parent-child relationships between roles
- Automatic inheritance of permissions
- Role type categorization (FUNCTIONAL, ACCESS, CUSTOM)

### Auto-Grant Roles
- Roles marked with `AUTO_GRANT = TRUE` are automatically assigned to all new users
- Useful for baseline permissions that every user should have

### Bulk Operations
- Create multiple users from configuration tables
- Consistent role assignments across user groups
- Audit trail for all operations

### Error Handling
- Comprehensive error handling with descriptive messages
- Graceful handling of existing users and roles
- Transaction safety for bulk operations

## Best Practices

1. **Role Design**: Create a clear role hierarchy with minimal privilege principle
2. **Configuration Management**: Use version control for configuration table changes
3. **Testing**: Test procedures in development environment before production deployment
4. **Monitoring**: Regularly audit user and role assignments
5. **Documentation**: Keep role descriptions up-to-date for compliance

## Security Considerations

- Passwords should be temporary and force users to change on first login
- Use SSO integration when possible (set PASSWORD to NULL)
- Regularly review and audit role assignments
- Implement approval workflows for sensitive role grants
- Monitor failed login attempts and disabled accounts

## Troubleshooting

### Common Issues

1. **"User already exists"**: The procedure will update role assignments for existing users
2. **"Role does not exist"**: Ensure all referenced roles exist in Snowflake before assignment
3. **"Insufficient privileges"**: Ensure the executing user has USERADMIN or SECURITYADMIN privileges

### Debugging

```sql
-- Check user configuration
SELECT * FROM USER_CONFIG WHERE USER_NAME = 'TARGET_USER';

-- Check role assignments
SELECT * FROM USER_ROLE_CONFIG WHERE USER_NAME = 'TARGET_USER';

-- Verify Snowflake user exists
SELECT * FROM INFORMATION_SCHEMA.USERS WHERE USER_NAME = 'TARGET_USER';

-- Check granted roles in Snowflake
SHOW GRANTS TO USER TARGET_USER;
```

