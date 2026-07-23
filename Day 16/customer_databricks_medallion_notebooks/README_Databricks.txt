CUSTOMER MEDALLION PIPELINE - DATABRICKS
========================================

FILES
-----
1. customer_Silver.py
2. customer_Gold.py

These are Databricks source-format notebooks. The markers
"# Databricks notebook source" and "# COMMAND ----------" preserve notebook cells
when imported into Databricks.

IMPORT
------
Databricks Workspace > your folder > Import > File

Import both .py files, then run them in this order:

1. Existing customer_Bronze notebook
2. customer_Silver
3. customer_Gold

REQUIRED SECRET
---------------
Scope: azure-storage
Key:   storage-account-key

Do not place the Azure Storage access key directly in a notebook.

DATA FLOW
---------
customers-100.csv
  -> Bronze CSV: bronze/customer
  -> Silver Delta: silver/customer
  -> Rejected Delta: silver/customer_rejected
  -> Gold Delta reports:
       gold/customer_kpi
       gold/customer_country_report
       gold/customer_monthly_report
       gold/customer_email_domain_report

TEMPORARY VIEWS
---------------
Silver:
  customer_bronze_vw
  customer_silver_vw
  customer_rejected_vw

Gold:
  customer_silver_vw
  gold_customer_kpi_vw
  gold_country_report_vw
  gold_monthly_report_vw
  gold_email_domain_report_vw

Temporary views exist only within the notebook Spark session. The Delta files
are the persisted layer outputs.
