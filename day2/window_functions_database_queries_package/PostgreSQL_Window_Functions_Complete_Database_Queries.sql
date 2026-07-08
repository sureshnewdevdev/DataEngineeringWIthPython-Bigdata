/* ============================================================
   POSTGRESQL COMPLETE SCRIPT
   Topic: SQL Window Functions

   Important:
   1. Run CREATE DATABASE first.
   2. Connect manually to window_functions_training_db.
   3. Then run the remaining script.
   ============================================================ */

-- Run this separately if database does not exist:
-- CREATE DATABASE window_functions_training_db;

DROP TABLE IF EXISTS sales_orders;
DROP TABLE IF EXISTS employees;

CREATE TABLE sales_orders (
    order_id        INT PRIMARY KEY,
    order_date      DATE NOT NULL,
    region          VARCHAR(50) NOT NULL,
    city            VARCHAR(50) NOT NULL,
    salesperson     VARCHAR(100) NOT NULL,
    product         VARCHAR(100) NOT NULL,
    category        VARCHAR(50) NOT NULL,
    quantity        INT NOT NULL,
    unit_price      NUMERIC(10,2) NOT NULL,
    order_amount    NUMERIC(10,2) NOT NULL
);

CREATE TABLE employees (
    employee_id     INT PRIMARY KEY,
    employee_name   VARCHAR(100) NOT NULL,
    department_id   INT NOT NULL,
    department_name VARCHAR(100) NOT NULL,
    job_title       VARCHAR(100) NOT NULL,
    salary          NUMERIC(10,2) NOT NULL,
    joining_date    DATE NOT NULL,
    city            VARCHAR(50) NOT NULL
);

INSERT INTO sales_orders
(order_id, order_date, region, city, salesperson, product, category, quantity, unit_price, order_amount)
VALUES
(1,  '2026-01-02', 'South', 'Bengaluru',  'Arun',  'Laptop',       'Electronics', 2, 65000, 130000),
(2,  '2026-01-04', 'South', 'Chennai',    'Priya', 'Keyboard',     'Electronics', 5, 1500,   7500),
(3,  '2026-01-05', 'West',  'Mumbai',     'Ravi',  'Office Chair', 'Furniture',   3, 8500,  25500),
(4,  '2026-01-07', 'North', 'Delhi',      'Neha',  'Monitor',      'Electronics', 4, 12000, 48000),
(5,  '2026-01-10', 'South', 'Bengaluru',  'Arun',  'Mouse',        'Electronics', 10, 800,   8000),
(6,  '2026-01-12', 'West',  'Pune',       'Ravi',  'Desk',         'Furniture',   2, 15000, 30000),
(7,  '2026-01-15', 'North', 'Delhi',      'Neha',  'Laptop',       'Electronics', 1, 68000, 68000),
(8,  '2026-01-17', 'East',  'Kolkata',    'Amit',  'Printer',      'Electronics', 2, 18000, 36000),
(9,  '2026-01-20', 'South', 'Hyderabad',  'Priya', 'Chair',        'Furniture',   6, 7000,  42000),
(10, '2026-01-22', 'West',  'Mumbai',     'Ravi',  'Monitor',      'Electronics', 3, 12500, 37500),
(11, '2026-01-25', 'North', 'Jaipur',     'Neha',  'Table',        'Furniture',   4, 9500,  38000),
(12, '2026-01-28', 'East',  'Kolkata',    'Amit',  'Laptop',       'Electronics', 1, 70000, 70000),
(13, '2026-02-01', 'South', 'Bengaluru',  'Arun',  'Desk',         'Furniture',   2, 14500, 29000),
(14, '2026-02-03', 'South', 'Chennai',    'Priya', 'Monitor',      'Electronics', 2, 11800, 23600),
(15, '2026-02-05', 'West',  'Pune',       'Ravi',  'Keyboard',     'Electronics', 8, 1400,  11200),
(16, '2026-02-07', 'North', 'Delhi',      'Neha',  'Mouse',        'Electronics', 12, 750,  9000),
(17, '2026-02-10', 'East',  'Bhubaneswar','Amit',  'Office Chair', 'Furniture',   5, 8200,  41000),
(18, '2026-02-12', 'South', 'Hyderabad',  'Priya', 'Laptop',       'Electronics', 2, 66000, 132000),
(19, '2026-02-14', 'West',  'Mumbai',     'Ravi',  'Table',        'Furniture',   3, 9200,  27600),
(20, '2026-02-16', 'North', 'Jaipur',     'Neha',  'Printer',      'Electronics', 1, 17500, 17500),
(21, '2026-02-18', 'East',  'Kolkata',    'Amit',  'Desk',         'Furniture',   2, 15500, 31000),
(22, '2026-02-20', 'South', 'Bengaluru',  'Arun',  'Monitor',      'Electronics', 3, 12100, 36300),
(23, '2026-02-22', 'West',  'Pune',       'Ravi',  'Laptop',       'Electronics', 1, 69000, 69000),
(24, '2026-02-25', 'North', 'Delhi',      'Neha',  'Office Chair', 'Furniture',   4, 8300,  33200),
(25, '2026-02-27', 'East',  'Bhubaneswar','Amit',  'Keyboard',     'Electronics', 6, 1450,  8700),
(26, '2026-03-01', 'South', 'Chennai',    'Priya', 'Printer',      'Electronics', 1, 19000, 19000),
(27, '2026-03-03', 'North', 'Delhi',      'Neha',  'Desk',         'Furniture',   2, 16000, 32000),
(28, '2026-03-05', 'West',  'Mumbai',     'Ravi',  'Laptop',       'Electronics', 2, 67000, 134000),
(29, '2026-03-07', 'East',  'Kolkata',    'Amit',  'Monitor',      'Electronics', 2, 12200, 24400),
(30, '2026-03-10', 'South', 'Bengaluru',  'Arun',  'Table',        'Furniture',   3, 9800,  29400);

INSERT INTO employees
(employee_id, employee_name, department_id, department_name, job_title, salary, joining_date, city)
VALUES
(101, 'Aarav Sharma', 10, 'Data Engineering', 'Data Engineer',        85000,  '2024-01-10', 'Bengaluru'),
(102, 'Diya Patel',   10, 'Data Engineering', 'Senior Data Engineer', 125000, '2023-05-15', 'Hyderabad'),
(103, 'Kiran Rao',    10, 'Data Engineering', 'ETL Developer',        78000,  '2025-02-20', 'Chennai'),
(104, 'Meera Nair',   10, 'Data Engineering', 'Data Architect',       150000, '2022-08-01', 'Bengaluru'),
(105, 'Rahul Verma',  20, 'Application Dev',  'Software Engineer',    72000,  '2024-06-12', 'Pune'),
(106, 'Sneha Iyer',   20, 'Application Dev',  'Senior Developer',     115000, '2023-03-19', 'Mumbai'),
(107, 'Vikram Singh', 20, 'Application Dev',  'Tech Lead',            140000, '2021-11-25', 'Delhi'),
(108, 'Ananya Gupta', 20, 'Application Dev',  'Software Engineer',    72000,  '2025-01-05', 'Noida'),
(109, 'Rohan Das',    30, 'Quality Assurance','QA Engineer',          65000,  '2024-09-01', 'Kolkata'),
(110, 'Pooja Menon',  30, 'Quality Assurance','Automation Tester',    90000,  '2023-10-10', 'Bengaluru'),
(111, 'Sanjay Kumar', 30, 'Quality Assurance','QA Lead',              118000, '2022-12-18', 'Chennai'),
(112, 'Nisha Reddy',  30, 'Quality Assurance','Performance Tester',   97000,  '2023-07-07', 'Hyderabad'),
(113, 'Imran Khan',   40, 'Cloud Operations', 'Cloud Engineer',       98000,  '2023-02-13', 'Mumbai'),
(114, 'Lakshmi Devi', 40, 'Cloud Operations', 'DevOps Engineer',      110000, '2022-06-22', 'Bengaluru'),
(115, 'Arjun Mehta',  40, 'Cloud Operations', 'Cloud Architect',      155000, '2021-04-04', 'Pune'),
(116, 'Fatima Begum', 40, 'Cloud Operations', 'SRE Engineer',         108000, '2024-04-17', 'Delhi');

/* ============================================================
   SECTION 3: QUERIES FROM THE WINDOW FUNCTIONS TUTORIAL DOCUMENT
   ============================================================ */

/* Query 1: Basic Window Aggregate - Grand Total with Every Row */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    SUM(order_amount) OVER() AS grand_total
FROM sales_orders
ORDER BY order_id;

/* Query 2: Region-wise Total Without GROUP BY */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    SUM(order_amount) OVER(PARTITION BY region) AS region_total
FROM sales_orders
ORDER BY region, order_id;

/* Query 3: Running Total by Date */
SELECT
    order_id,
    order_date,
    order_amount,
    SUM(order_amount) OVER(
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM sales_orders
ORDER BY order_date, order_id;

/* Query 4: Row Number by Region */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    ROW_NUMBER() OVER(PARTITION BY region ORDER BY order_amount DESC, order_id) AS row_num
FROM sales_orders
ORDER BY region, row_num;

/* Query 5: RANK and DENSE_RANK by Region */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    RANK() OVER(PARTITION BY region ORDER BY order_amount DESC) AS sales_rank,
    DENSE_RANK() OVER(PARTITION BY region ORDER BY order_amount DESC) AS dense_sales_rank
FROM sales_orders
ORDER BY region, sales_rank, order_id;

/* Query 6: Top 2 Orders Per Region */
WITH ranked_orders AS (
    SELECT
        order_id,
        region,
        salesperson,
        order_amount,
        ROW_NUMBER() OVER(PARTITION BY region ORDER BY order_amount DESC, order_id) AS rn
    FROM sales_orders
)
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    rn
FROM ranked_orders
WHERE rn <= 2
ORDER BY region, rn;

/* Query 7: LAG and LEAD - Previous and Next Order Amount by Salesperson */
SELECT
    order_id,
    order_date,
    salesperson,
    order_amount,
    LAG(order_amount) OVER(PARTITION BY salesperson ORDER BY order_date, order_id) AS previous_order_amount,
    LEAD(order_amount) OVER(PARTITION BY salesperson ORDER BY order_date, order_id) AS next_order_amount
FROM sales_orders
ORDER BY salesperson, order_date, order_id;

/* Query 8: Difference from Previous Order */
SELECT
    order_id,
    order_date,
    salesperson,
    order_amount,
    order_amount - LAG(order_amount) OVER(PARTITION BY salesperson ORDER BY order_date, order_id) AS difference_from_previous
FROM sales_orders
ORDER BY salesperson, order_date, order_id;

/* Query 9: FIRST_VALUE and LAST_VALUE by Salesperson */
SELECT
    order_id,
    salesperson,
    order_date,
    order_amount,
    FIRST_VALUE(order_amount) OVER(
        PARTITION BY salesperson
        ORDER BY order_date, order_id
    ) AS first_order_amount,
    LAST_VALUE(order_amount) OVER(
        PARTITION BY salesperson
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS last_order_amount
FROM sales_orders
ORDER BY salesperson, order_date, order_id;

/* Query 10: Moving Average of Last 3 Orders */
SELECT
    order_id,
    order_date,
    order_amount,
    AVG(order_amount) OVER(
        ORDER BY order_date, order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_last_3_orders
FROM sales_orders
ORDER BY order_date, order_id;

/* Query 11: Percentage Contribution to Region Sales */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    ROUND(
        order_amount * 100.0 /
        SUM(order_amount) OVER(PARTITION BY region), 2
    ) AS percentage_of_region_sales
FROM sales_orders
ORDER BY region, order_amount DESC;

/* Query 12: Ranking Comparison - ROW_NUMBER, RANK, DENSE_RANK */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    ROW_NUMBER() OVER(PARTITION BY region ORDER BY order_amount DESC, order_id) AS row_number_value,
    RANK() OVER(PARTITION BY region ORDER BY order_amount DESC) AS rank_value,
    DENSE_RANK() OVER(PARTITION BY region ORDER BY order_amount DESC) AS dense_rank_value
FROM sales_orders
ORDER BY region, order_amount DESC, order_id;

/* Query 13: NTILE - Divide Orders into 4 Sales Buckets */
SELECT
    order_id,
    region,
    salesperson,
    order_amount,
    NTILE(4) OVER(ORDER BY order_amount DESC, order_id) AS sales_bucket
FROM sales_orders
ORDER BY sales_bucket, order_amount DESC;

/* Query 14: Salesperson-wise Running Total */
SELECT
    order_id,
    order_date,
    salesperson,
    order_amount,
    SUM(order_amount) OVER(
        PARTITION BY salesperson
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS salesperson_running_total
FROM sales_orders
ORDER BY salesperson, order_date, order_id;

/* Query 15: Category-wise Average and Difference from Category Average */
SELECT
    order_id,
    category,
    product,
    order_amount,
    AVG(order_amount) OVER(PARTITION BY category) AS category_average,
    order_amount - AVG(order_amount) OVER(PARTITION BY category) AS difference_from_category_average
FROM sales_orders
ORDER BY category, order_amount DESC;

/* Query 16: Deduplication Style Query - Latest Order Per Salesperson */
WITH latest_order AS (
    SELECT
        order_id,
        order_date,
        salesperson,
        product,
        order_amount,
        ROW_NUMBER() OVER(PARTITION BY salesperson ORDER BY order_date DESC, order_id DESC) AS rn
    FROM sales_orders
)
SELECT
    order_id,
    order_date,
    salesperson,
    product,
    order_amount
FROM latest_order
WHERE rn = 1
ORDER BY salesperson;

/* Query 17: First and Latest Product Sold by Each Salesperson */
SELECT
    order_id,
    salesperson,
    order_date,
    product,
    FIRST_VALUE(product) OVER(
        PARTITION BY salesperson
        ORDER BY order_date, order_id
    ) AS first_product_sold,
    LAST_VALUE(product) OVER(
        PARTITION BY salesperson
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS latest_product_sold
FROM sales_orders
ORDER BY salesperson, order_date, order_id;

/* Query 18: Interview Query from Document - Top 2 Employees by Salary in Each Department */
WITH ranked_employees AS (
    SELECT
        employee_id,
        employee_name,
        department_id,
        salary,
        ROW_NUMBER() OVER(
            PARTITION BY department_id
            ORDER BY salary DESC, employee_id
        ) AS rn
    FROM employees
)
SELECT
    employee_id,
    employee_name,
    department_id,
    salary,
    rn
FROM ranked_employees
WHERE rn <= 2
ORDER BY department_id, rn;

/* Query 19: Department-wise Salary Rank */
SELECT
    employee_id,
    employee_name,
    department_id,
    salary,
    RANK() OVER(PARTITION BY department_id ORDER BY salary DESC) AS salary_rank,
    DENSE_RANK() OVER(PARTITION BY department_id ORDER BY salary DESC) AS dense_salary_rank
FROM employees
ORDER BY department_id, salary_rank, employee_id;

/* Query 20: Employee Salary Compared with Department Average */
SELECT
    employee_id,
    employee_name,
    department_id,
    salary,
    AVG(salary) OVER(PARTITION BY department_id) AS department_avg_salary,
    salary - AVG(salary) OVER(PARTITION BY department_id) AS difference_from_department_avg
FROM employees
ORDER BY department_id, salary DESC;

/* Query 21: Employee Previous and Next Salary Within Department */
SELECT
    employee_id,
    employee_name,
    department_id,
    salary,
    LAG(salary) OVER(PARTITION BY department_id ORDER BY salary DESC, employee_id) AS previous_higher_salary,
    LEAD(salary) OVER(PARTITION BY department_id ORDER BY salary DESC, employee_id) AS next_lower_salary
FROM employees
ORDER BY department_id, salary DESC, employee_id;
