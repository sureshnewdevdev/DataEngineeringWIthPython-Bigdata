Window Functions Database and Queries Package

Created for the SQL Window Functions tutorial document.

Files:
1. SQL_Server_Window_Functions_Complete_Database_Queries.sql
   - Best option if you are using Microsoft SQL Server.
   - Creates database: WindowFunctionsTrainingDB
   - Creates tables: sales_orders, employees
   - Inserts records
   - Includes all tutorial queries from the document.

2. PostgreSQL_Window_Functions_Complete_Database_Queries.sql
   - For PostgreSQL.
   - Create database manually or run CREATE DATABASE separately.
   - Then connect to the database and run the script.

3. Oracle_Window_Functions_Complete_Schema_Queries.sql
   - For Oracle.
   - Oracle usually works with schema/user, not CREATE DATABASE inside a normal script.
   - Run this inside your existing Oracle schema.

Tables included:
1. sales_orders
   - 30 records
   - Used for SUM OVER, PARTITION BY, ROW_NUMBER, RANK, DENSE_RANK, NTILE, LAG, LEAD, FIRST_VALUE, LAST_VALUE, running total, and moving average.

2. employees
   - 16 records
   - Used for the interview query from the tutorial: Top 2 employees by salary in each department.

How to use:
- SQL Server: open the SQL Server script in SSMS / Azure Data Studio and run all.
- PostgreSQL: create/connect to database, then run the PostgreSQL script.
- Oracle: run the Oracle script in SQL Developer inside your schema.

Important:
The scripts include the queries from the HTML tutorial document and additional practice queries with the same dataset.
