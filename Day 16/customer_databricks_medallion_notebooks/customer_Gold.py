# Databricks notebook source
# MAGIC %md
# MAGIC # Customer Gold Layer and Analysis Report
# MAGIC Reads cleaned Silver Delta data, creates temporary views, produces business
# MAGIC summaries, saves each report in Delta format, and displays a final report.

# COMMAND ----------

from pyspark.sql import functions as F

storage_account_name = "newstoreforsession"
container_name = "datasource"

storage_account_key = dbutils.secrets.get(
    scope="azure-storage",
    key="storage-account-key"
)

spark.conf.set(
    f"fs.azure.account.key.{storage_account_name}.blob.core.windows.net",
    storage_account_key
)

silver_input_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "silver/customer"
)
gold_base_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/gold"
)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1. Read Silver and create a temporary view

# COMMAND ----------

df_silver = spark.read.format("delta").load(silver_input_path)
df_silver.createOrReplaceTempView("customer_silver_vw")

print("Silver records:", df_silver.count())
display(spark.sql("SELECT * FROM customer_silver_vw LIMIT 20"))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2. Gold report: executive KPIs

# COMMAND ----------

df_customer_kpi = spark.sql("""
SELECT
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT country) AS total_countries,
    COUNT(DISTINCT city) AS total_cities,
    COUNT(DISTINCT company) AS total_companies,
    MIN(subscription_date) AS first_subscription_date,
    MAX(subscription_date) AS latest_subscription_date
FROM customer_silver_vw
""")

df_customer_kpi.createOrReplaceTempView("gold_customer_kpi_vw")
display(df_customer_kpi)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3. Gold report: customers by country

# COMMAND ----------

df_country_report = spark.sql("""
WITH country_totals AS (
    SELECT
        country,
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(DISTINCT city) AS total_cities,
        COUNT(DISTINCT company) AS total_companies,
        MIN(subscription_date) AS first_subscription_date,
        MAX(subscription_date) AS latest_subscription_date
    FROM customer_silver_vw
    GROUP BY country
)
SELECT
    *,
    ROUND(
        total_customers * 100.0 / SUM(total_customers) OVER (),
        2
    ) AS customer_percentage
FROM country_totals
ORDER BY total_customers DESC, country
""")

df_country_report.createOrReplaceTempView("gold_country_report_vw")
display(df_country_report)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4. Gold report: monthly subscription trend

# COMMAND ----------

df_monthly_report = spark.sql("""
SELECT
    DATE_FORMAT(subscription_date, 'yyyy-MM') AS subscription_month,
    COUNT(DISTINCT customer_id) AS new_customers,
    COUNT(DISTINCT country) AS countries_represented,
    COUNT(DISTINCT company) AS companies_represented
FROM customer_silver_vw
GROUP BY DATE_FORMAT(subscription_date, 'yyyy-MM')
ORDER BY subscription_month
""")

df_monthly_report.createOrReplaceTempView("gold_monthly_report_vw")
display(df_monthly_report)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5. Gold report: top email domains

# COMMAND ----------

df_email_domain_report = spark.sql("""
SELECT
    email_domain,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0 /
        SUM(COUNT(DISTINCT customer_id)) OVER (),
        2
    ) AS customer_percentage
FROM customer_silver_vw
WHERE email_domain IS NOT NULL AND TRIM(email_domain) <> ''
GROUP BY email_domain
ORDER BY total_customers DESC, email_domain
""")

df_email_domain_report.createOrReplaceTempView("gold_email_domain_report_vw")
display(df_email_domain_report)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6. Save Gold reports in Databricks Delta format

# COMMAND ----------

gold_reports = {
    "customer_kpi": df_customer_kpi,
    "customer_country_report": df_country_report,
    "customer_monthly_report": df_monthly_report,
    "customer_email_domain_report": df_email_domain_report
}

for report_name, report_df in gold_reports.items():
    output_path = f"{gold_base_path}/{report_name}"
    (
        report_df
        .withColumn("_gold_processed_timestamp", F.current_timestamp())
        .write
        .format("delta")
        .mode("overwrite")
        .option("overwriteSchema", "true")
        .save(output_path)
    )
    print(f"Saved {report_name}: {output_path}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 7. Final management report

# COMMAND ----------

print("CUSTOMER GOLD REPORT")
print("=" * 60)
print("1. Executive KPIs")
display(spark.sql("SELECT * FROM gold_customer_kpi_vw"))

print("2. Top 10 countries")
display(spark.sql("""
SELECT *
FROM gold_country_report_vw
ORDER BY total_customers DESC
LIMIT 10
"""))

print("3. Monthly subscription trend")
display(spark.sql("SELECT * FROM gold_monthly_report_vw"))

print("4. Top 10 email domains")
display(spark.sql("""
SELECT *
FROM gold_email_domain_report_vw
ORDER BY total_customers DESC
LIMIT 10
"""))

