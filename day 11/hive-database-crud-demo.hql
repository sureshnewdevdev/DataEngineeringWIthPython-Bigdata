-- ==============================================================
-- Hive Database Operations and CRUD Demo
-- Domain: Company HR Employee Management
-- Run using Beeline after HiveServer2 is available.
-- ============================================================== 

-- Optional session settings for ACID operations.
-- Your administrator may already have configured these in hive-site.xml.
SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
SET hive.exec.dynamic.partition.mode=nonstrict;
-- Required only by older Hive releases; harmless as a session setting.
SET hive.enforce.bucketing=true;

-- --------------------------------------------------------------
-- 1. DATABASE CREATE
-- --------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS company_hr
COMMENT 'Training database for employee CRUD operations'
WITH DBPROPERTIES (
  'created_by'='ItTechGenie Training',
  'purpose'='Hive CRUD demonstration'
);

-- --------------------------------------------------------------
-- 2. DATABASE READ / INSPECTION
-- --------------------------------------------------------------
SHOW DATABASES LIKE 'company*';
DESCRIBE DATABASE EXTENDED company_hr;
USE company_hr;
SELECT current_database();

-- --------------------------------------------------------------
-- 3. DATABASE UPDATE (metadata)
-- --------------------------------------------------------------
ALTER DATABASE company_hr SET DBPROPERTIES (
  'environment'='training',
  'owner_team'='data_engineering'
);
DESCRIBE DATABASE EXTENDED company_hr;

-- --------------------------------------------------------------
-- 4. CREATE A TRANSACTIONAL ORC TABLE
-- Bucketing maximizes compatibility with older Hive ACID releases.
-- --------------------------------------------------------------
DROP TABLE IF EXISTS employees;
CREATE TABLE employees (
  employee_id   INT,
  employee_name STRING,
  department    STRING,
  salary        DECIMAL(12,2),
  joining_date  DATE,
  employment_status STRING
)
CLUSTERED BY (employee_id) INTO 4 BUCKETS
STORED AS ORC
TBLPROPERTIES ('transactional'='true');

SHOW TABLES;
DESCRIBE FORMATTED employees;
SHOW TBLPROPERTIES employees;

-- --------------------------------------------------------------
-- 5. CREATE ROWS: INSERT
-- --------------------------------------------------------------
INSERT INTO TABLE employees VALUES
(101, 'Asha',   'Data Engineering', 75000.00, DATE '2024-02-15', 'ACTIVE'),
(102, 'Bharat', 'Finance',          62000.00, DATE '2023-08-10', 'ACTIVE'),
(103, 'Charan', 'Human Resources',  58000.00, DATE '2022-11-01', 'ACTIVE'),
(104, 'Divya',  'Data Engineering', 81000.00, DATE '2021-06-19', 'ACTIVE'),
(105, 'Eshan',  'Support',          45000.00, DATE '2025-01-06', 'INACTIVE'),
(106, 'Farah',  'Finance',          69000.00, DATE '2020-04-27', 'ACTIVE');

-- --------------------------------------------------------------
-- 6. READ ROWS: SELECT
-- --------------------------------------------------------------
SELECT * FROM employees ORDER BY employee_id;

SELECT employee_id, employee_name, salary
FROM employees
WHERE department = 'Data Engineering'
ORDER BY salary DESC;

SELECT department,
       COUNT(*) AS employee_count,
       ROUND(AVG(salary), 2) AS average_salary
FROM employees
GROUP BY department
ORDER BY department;

-- --------------------------------------------------------------
-- 7. UPDATE ROWS
-- --------------------------------------------------------------
UPDATE employees
SET salary = salary * 1.10
WHERE department = 'Data Engineering';

UPDATE employees
SET employment_status = 'ACTIVE'
WHERE employee_id = 105;

SELECT * FROM employees ORDER BY employee_id;

-- --------------------------------------------------------------
-- 8. DELETE ROWS
-- --------------------------------------------------------------
DELETE FROM employees
WHERE employee_id = 103;

SELECT * FROM employees ORDER BY employee_id;

-- --------------------------------------------------------------
-- 9. OPTIONAL: BULK LOAD THROUGH A TEXT STAGING TABLE
-- Download employees-sample.csv and change the local path if needed.
-- --------------------------------------------------------------
DROP TABLE IF EXISTS employees_stage;
CREATE TABLE employees_stage (
  employee_id INT,
  employee_name STRING,
  department STRING,
  salary DECIMAL(12,2),
  joining_date DATE,
  employment_status STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='1');

-- Example path for the user's Ubuntu VM:
-- LOAD DATA LOCAL INPATH '/home/vmuser/Desktop/employees-sample.csv'
-- OVERWRITE INTO TABLE employees_stage;
-- INSERT INTO TABLE employees SELECT * FROM employees_stage;

-- --------------------------------------------------------------
-- 10. CLEAN-UP OPTIONS (RUN CAREFULLY)
-- --------------------------------------------------------------
-- TRUNCATE TABLE employees;                 -- remove all rows, keep table
-- DROP TABLE employees;                     -- remove table and managed data
-- USE default;
-- DROP DATABASE company_hr RESTRICT;        -- succeeds only when empty
-- DROP DATABASE company_hr CASCADE;         -- removes database and contained objects
