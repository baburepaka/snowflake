# Snowflake Table Policy Management System

This repository contains a comprehensive Snowflake procedure system for applying table policies (row access policies and column masking policies) based on configuration stored in a mapping table.

## 📋 Table of Contents
- [Overview](#overview)
- [Configuration Table Structure](#configuration-table-structure)
- [Procedures](#procedures)
- [Usage](#usage)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

The system provides automated policy application based on a configuration-driven approach. It supports:

- **Row Access Policies**: Control which rows users can see
- **Column Masking Policies**: Control how sensitive data is displayed
- **Batch Processing**: Apply multiple policies in priority order
- **Error Handling**: Graceful handling of individual policy failures
- **Validation**: Pre-application validation of configuration
- **Rollback**: Ability to remove all applied policies

## 🗃️ Configuration Table Structure

```sql
CREATE OR REPLACE TABLE DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING (
    PRIORITY VARCHAR(50),           -- Processing order (lower numbers first)
    TABLENAME VARCHAR(100),         -- Fully qualified table name
    COLUMNNAME VARCHAR(100),        -- Column name (NULL for row access policies)
    DIRECTTABLE VARCHAR(10),        -- 'Y' for direct, 'N' for indirect
    INDIRECTTABLE VARCHAR(100),     -- Reference table for indirect policies
    INDIRECTTABLECOLUMN VARCHAR(100), -- Column in reference table
    ASSIGNEDPOLICY VARCHAR(100),    -- Name of policy to apply
    COMMENTS VARCHAR(255)           -- Description/notes
);
```

### Field Descriptions

| Field | Purpose | Required | Notes |
|-------|---------|----------|-------|
| `PRIORITY` | Processing order | Recommended | Lower numbers processed first |
| `TABLENAME` | Target table | **Required** | Format: `database.schema.table` |
| `COLUMNNAME` | Target column | Conditional | Required for masking policies, NULL for row access |
| `DIRECTTABLE` | Policy type flag | Optional | 'Y' for direct table policies |
| `INDIRECTTABLE` | Reference table | Optional | For complex policy scenarios |
| `INDIRECTTABLECOLUMN` | Reference column | Optional | For row access policies: Column to apply the ON clause (e.g., "ON (BUSINESS_UNIT)") |
| `ASSIGNEDPOLICY` | Policy name | **Required** | Must exist in Snowflake |
| `COMMENTS` | Documentation | Optional | Helpful for maintenance |

## 🔧 Procedures

### 1. `APPLY_TABLE_POLICIES()`
**Main procedure** that applies all policies from the configuration table.

```sql
CALL DBCSUDL.CHRS.APPLY_TABLE_POLICIES();
```

**Features:**
- Processes policies in priority order
- Handles both row access and column masking policies
- Continues processing even if individual policies fail
- Returns detailed execution report

### 2. `VALIDATE_POLICY_CONFIGURATION()`
**Validation procedure** that checks configuration before applying policies.

```sql
CALL DBCSUDL.CHRS.VALIDATE_POLICY_CONFIGURATION();
```

**Checks:**
- Required fields are populated
- Policy names are valid
- Table names are properly formatted
- Returns validation report with errors and warnings

### 3. `REMOVE_APPLIED_POLICIES()`
**Rollback procedure** that removes all policies defined in the configuration.

```sql
CALL DBCSUDL.CHRS.REMOVE_APPLIED_POLICIES();
```

**Use Cases:**
- Testing and development
- Emergency rollback
- Policy reconfiguration

## 🚀 Usage

### Step 1: Populate Configuration Table
```sql
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
('1', 'DBCSUDL.CHRS.CUSTOMER_DATA', 'SSN', 'Y', NULL, NULL, 'SSN_MASKING_POLICY', 'Mask SSN'),
('2', 'DBCSUDL.CHRS.CUSTOMER_DATA', NULL, 'Y', NULL, NULL, 'CUSTOMER_ROW_POLICY', 'Row access control');
```

### Step 2: Validate Configuration
```sql
CALL DBCSUDL.CHRS.VALIDATE_POLICY_CONFIGURATION();
```

### Step 3: Apply Policies
```sql
CALL DBCSUDL.CHRS.APPLY_TABLE_POLICIES();
```

### Step 4: Verify Application
```sql
-- Check applied policies
SELECT TABLE_NAME, POLICY_KIND, POLICY_NAME 
FROM INFORMATION_SCHEMA.POLICY_REFERENCES 
WHERE TABLE_SCHEMA = 'CHRS';
```

## 📚 Examples

### Row Access Policy Configuration
```sql
-- Apply row access policy to entire table
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
('1', 'DBCSUDL.CHRS.EMPLOYEE_DATA', NULL, 'Y', NULL, NULL, 'HR_ROW_ACCESS_POLICY', 'Restrict by department');

-- Apply row access policy with ON clause (specific column)
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
('2', 'DBCSUDL.CHRS.DL_POSITION_DATA', NULL, 'Y', NULL, 'BUSINESS_UNIT', 'PS_CHRS_BUSINESS_UNIT_POLICY', 'Apply on BUSINESS_UNIT column');
```

This will generate SQL like:
```sql
-- For standard row access policy:
ALTER TABLE DBCSUDL.CHRS.EMPLOYEE_DATA ADD ROW ACCESS POLICY HR_ROW_ACCESS_POLICY;

-- For row access policy with ON clause:
ALTER TABLE DBCSUDL.CHRS.DL_POSITION_DATA ADD ROW ACCESS POLICY PS_CHRS_BUSINESS_UNIT_POLICY ON (BUSINESS_UNIT);
```

### Column Masking Policy Configuration
```sql
-- Apply masking policy to specific column
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
('2', 'DBCSUDL.CHRS.CUSTOMER_DATA', 'EMAIL', 'Y', NULL, NULL, 'EMAIL_MASKING_POLICY', 'Mask email addresses');
```

### Multiple Policies on Same Table
```sql
-- Multiple policies with different priorities
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
('1', 'DBCSUDL.CHRS.SENSITIVE_DATA', NULL, 'Y', NULL, NULL, 'ROW_ACCESS_POLICY', 'Row level security'),
('2', 'DBCSUDL.CHRS.SENSITIVE_DATA', 'SSN', 'Y', NULL, NULL, 'SSN_MASK', 'Mask SSN column'),
('3', 'DBCSUDL.CHRS.SENSITIVE_DATA', 'SALARY', 'Y', NULL, NULL, 'SALARY_MASK', 'Mask salary column');
```

## ✅ Best Practices

### 1. **Priority Management**
- Use incremental priorities (1, 2, 3...)
- Leave gaps for future insertions (10, 20, 30...)
- Apply row access policies before column masking policies

### 2. **Policy Naming**
- Use descriptive, consistent naming conventions
- Include policy type in name (e.g., `CUSTOMER_ROW_ACCESS`, `SSN_MASKING`)
- Avoid special characters and spaces

### 3. **Testing Strategy**
```sql
-- Always validate before applying
CALL DBCSUDL.CHRS.VALIDATE_POLICY_CONFIGURATION();

-- Test on development environment first
-- Apply policies in small batches
-- Verify results before proceeding
```

### 4. **Error Handling**
- Review procedure output for errors
- Individual policy failures don't stop the process
- Keep detailed comments for troubleshooting

### 5. **Documentation**
- Use the COMMENTS field extensively
- Document policy purpose and business rules
- Maintain change log for policy modifications

## 🔍 Troubleshooting

### Common Issues

#### 1. **Policy Not Found Error**
```
ERROR: Policy 'MY_POLICY' does not exist
```
**Solution:** Ensure the policy exists before applying:
```sql
SHOW MASKING POLICIES;
SHOW ROW ACCESS POLICIES;
```

#### 2. **Table Not Found Error**
```
ERROR: Table 'DBCSUDL.CHRS.MY_TABLE' does not exist
```
**Solution:** Verify table name format and existence:
```sql
SHOW TABLES IN SCHEMA DBCSUDL.CHRS;
```

#### 3. **Column Not Found Error**
```
ERROR: Column 'MY_COLUMN' does not exist in table
```
**Solution:** Check column names:
```sql
DESCRIBE TABLE DBCSUDL.CHRS.MY_TABLE;
```

#### 4. **Permission Errors**
```
ERROR: Insufficient privileges to apply policy
```
**Solution:** Ensure proper role permissions:
- `APPLY` privilege on policies
- `ALTER` privilege on tables
- Appropriate role hierarchy

### Debugging Queries

```sql
-- Check current policy assignments
SELECT * FROM INFORMATION_SCHEMA.POLICY_REFERENCES 
WHERE TABLE_SCHEMA = 'CHRS';

-- Verify policy existence
SELECT POLICY_NAME, POLICY_KIND 
FROM INFORMATION_SCHEMA.POLICIES 
WHERE POLICY_SCHEMA = 'CHRS';

-- Check table structure
DESCRIBE TABLE DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING;

-- Review configuration data
SELECT * FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING 
ORDER BY PRIORITY;
```

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Snowflake documentation for policy syntax
3. Validate configuration using the validation procedure
4. Test in development environment first

## 🔄 Version History

- **v1.0**: Initial implementation with basic policy application
- **v1.1**: Added validation and rollback procedures
- **v1.2**: Enhanced error handling and reporting
- **v1.3**: Added comprehensive documentation and examples
