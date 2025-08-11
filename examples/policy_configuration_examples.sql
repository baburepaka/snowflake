-- =====================================================
-- Sample Policy Configuration Examples
-- Description: Examples of how to populate the policy mapping table
-- =====================================================

-- Sample data for the policy mapping table
INSERT INTO DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING VALUES
-- Row Access Policies (COLUMNNAME is NULL)
('1', 'DBCSUDL.CHRS.CUSTOMER_DATA', NULL, 'Y', NULL, NULL, 'CUSTOMER_ROW_ACCESS_POLICY', 'Restrict customer data access by region'),
('2', 'DBCSUDL.CHRS.EMPLOYEE_DATA', NULL, 'Y', NULL, NULL, 'HR_ROW_ACCESS_POLICY', 'Restrict employee data access by department'),

-- Column Masking Policies (COLUMNNAME is specified)
('3', 'DBCSUDL.CHRS.CUSTOMER_DATA', 'SSN', 'Y', NULL, NULL, 'SSN_MASKING_POLICY', 'Mask Social Security Numbers'),
('4', 'DBCSUDL.CHRS.CUSTOMER_DATA', 'EMAIL', 'Y', NULL, NULL, 'EMAIL_MASKING_POLICY', 'Mask email addresses'),
('5', 'DBCSUDL.CHRS.EMPLOYEE_DATA', 'SALARY', 'Y', NULL, NULL, 'SALARY_MASKING_POLICY', 'Mask salary information'),
('6', 'DBCSUDL.CHRS.CUSTOMER_DATA', 'PHONE', 'Y', NULL, NULL, 'PHONE_MASKING_POLICY', 'Mask phone numbers'),

-- Indirect table policies (using reference tables)
('7', 'DBCSUDL.CHRS.TRANSACTION_DATA', NULL, 'N', 'DBCSUDL.CHRS.CUSTOMER_MAPPING', 'CUSTOMER_ID', 'TRANSACTION_ACCESS_POLICY', 'Control transaction access via customer mapping');

-- =====================================================
-- Sample Policy Definitions
-- Description: Example policies that would be referenced in the mapping table
-- =====================================================

-- Example Row Access Policy
CREATE OR REPLACE ROW ACCESS POLICY CUSTOMER_ROW_ACCESS_POLICY AS (
    CURRENT_ROLE() IN ('CUSTOMER_ADMIN', 'DATA_ANALYST') 
    OR 
    CURRENT_USER() = 'SYSTEM_USER'
);

-- Example Column Masking Policies
CREATE OR REPLACE MASKING POLICY SSN_MASKING_POLICY AS (VAL STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('HR_ADMIN', 'COMPLIANCE_OFFICER') THEN VAL
        WHEN CURRENT_ROLE() IN ('ANALYST', 'MANAGER') THEN 'XXX-XX-' || RIGHT(VAL, 4)
        ELSE 'XXX-XX-XXXX'
    END;

CREATE OR REPLACE MASKING POLICY EMAIL_MASKING_POLICY AS (VAL STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('MARKETING_ADMIN', 'CUSTOMER_SERVICE') THEN VAL
        WHEN CURRENT_ROLE() IN ('ANALYST') THEN LEFT(VAL, 3) || '***@' || SPLIT_PART(VAL, '@', 2)
        ELSE '***@***'
    END;

CREATE OR REPLACE MASKING POLICY SALARY_MASKING_POLICY AS (VAL NUMBER) RETURNS NUMBER ->
    CASE 
        WHEN CURRENT_ROLE() IN ('HR_ADMIN', 'PAYROLL_ADMIN') THEN VAL
        WHEN CURRENT_ROLE() IN ('MANAGER') THEN ROUND(VAL, -3) -- Round to nearest thousand
        ELSE NULL
    END;

CREATE OR REPLACE MASKING POLICY PHONE_MASKING_POLICY AS (VAL STRING) RETURNS STRING ->
    CASE 
        WHEN CURRENT_ROLE() IN ('CUSTOMER_SERVICE', 'SALES_ADMIN') THEN VAL
        WHEN CURRENT_ROLE() IN ('ANALYST') THEN '***-***-' || RIGHT(VAL, 4)
        ELSE '***-***-****'
    END;

-- =====================================================
-- Testing and Validation Queries
-- =====================================================

-- Check current policy mappings
SELECT 
    PRIORITY,
    TABLENAME,
    COLUMNNAME,
    ASSIGNEDPOLICY,
    COMMENTS,
    CASE 
        WHEN COLUMNNAME IS NULL OR COLUMNNAME = '' THEN 'Row Access Policy'
        ELSE 'Column Masking Policy'
    END AS POLICY_TYPE
FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING
ORDER BY PRIORITY;

-- Validate that all referenced policies exist
SELECT 
    m.ASSIGNEDPOLICY,
    m.TABLENAME,
    m.COLUMNNAME,
    CASE 
        WHEN p.POLICY_NAME IS NOT NULL THEN 'EXISTS'
        ELSE 'MISSING'
    END AS POLICY_STATUS
FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING m
LEFT JOIN INFORMATION_SCHEMA.POLICIES p ON m.ASSIGNEDPOLICY = p.POLICY_NAME
ORDER BY m.PRIORITY;

-- Check which tables have policies applied
SELECT 
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    POLICY_KIND,
    POLICY_NAME
FROM INFORMATION_SCHEMA.POLICY_REFERENCES
WHERE TABLE_SCHEMA = 'CHRS'
ORDER BY TABLE_NAME, POLICY_KIND;

-- =====================================================
-- Cleanup Scripts (for testing)
-- =====================================================

-- Clear all test data from mapping table
-- DELETE FROM DBCSUDL.CHRS.DL_CHRS_TABLE_POLICY_MAPPING;

-- Drop sample policies (uncomment if needed for cleanup)
-- DROP MASKING POLICY IF EXISTS SSN_MASKING_POLICY;
-- DROP MASKING POLICY IF EXISTS EMAIL_MASKING_POLICY;
-- DROP MASKING POLICY IF EXISTS SALARY_MASKING_POLICY;
-- DROP MASKING POLICY IF EXISTS PHONE_MASKING_POLICY;
-- DROP ROW ACCESS POLICY IF EXISTS CUSTOMER_ROW_ACCESS_POLICY;

