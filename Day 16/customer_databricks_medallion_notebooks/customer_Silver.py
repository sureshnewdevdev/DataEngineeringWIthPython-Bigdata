# Databricks notebook source
# MAGIC %md
# MAGIC # Customer Silver Layer
# MAGIC Reads the Bronze CSV output, creates a temporary view, cleans and validates
# MAGIC customer records, then stores valid and rejected data in Delta format.

# COMMAND ----------

from pyspark.sql import functions as F
import re

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

bronze_input_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "bronze/customer"
)
silver_output_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "silver/customer"
)
silver_rejected_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "silver/customer_rejected"
)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1. Read Bronze and create a temporary view

# COMMAND ----------

df_bronze = (
    spark.read
    .format("csv")
    .option("header", "true")
    .option("inferSchema", "true")
    .load(bronze_input_path)
)

df_bronze.createOrReplaceTempView("customer_bronze_vw")

print("Bronze records:", df_bronze.count())
display(spark.sql("SELECT * FROM customer_bronze_vw LIMIT 20"))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2. Standardize column names

# COMMAND ----------

def clean_column_name(name):
    return re.sub(r"[^a-zA-Z0-9]+", "_", name.strip().lower()).strip("_")

df_standardized = df_bronze
for old_name in df_bronze.columns:
    df_standardized = df_standardized.withColumnRenamed(
        old_name, clean_column_name(old_name)
    )

print(df_standardized.columns)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3. Filter and cleanse

# COMMAND ----------

df_prepared = (
    df_standardized
    .withColumn("customer_id", F.trim(F.col("customer_id").cast("string")))
    .withColumn("first_name", F.initcap(F.trim("first_name")))
    .withColumn("last_name", F.initcap(F.trim("last_name")))
    .withColumn("company", F.trim("company"))
    .withColumn("city", F.initcap(F.trim("city")))
    .withColumn("country", F.initcap(F.trim("country")))
    .withColumn("email", F.lower(F.trim("email")))
    .withColumn(
        "subscription_date",
        F.coalesce(
            F.to_date("subscription_date", "yyyy-MM-dd"),
            F.to_date("subscription_date", "dd-MM-yyyy"),
            F.to_date("subscription_date", "MM/dd/yyyy"),
            F.to_date("subscription_date", "dd/MM/yyyy")
        )
    )
    .withColumn("phone_1", F.regexp_replace(F.trim("phone_1"), r"[^0-9+]", ""))
    .withColumn("phone_2", F.regexp_replace(F.trim("phone_2"), r"[^0-9+]", ""))
    .withColumn("customer_full_name", F.concat_ws(" ", "first_name", "last_name"))
    .withColumn("email_domain", F.element_at(F.split("email", "@"), 2))
    .withColumn("subscription_year", F.year("subscription_date"))
    .withColumn("subscription_month", F.month("subscription_date"))
    .withColumn(
        "_is_email_valid",
        F.col("email").rlike(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
    )
    .withColumn("_silver_processed_timestamp", F.current_timestamp())
)

valid_condition = (
    F.col("customer_id").isNotNull()
    & (F.length("customer_id") > 0)
    & F.col("first_name").isNotNull()
    & (F.length("first_name") > 0)
    & F.col("last_name").isNotNull()
    & (F.length("last_name") > 0)
    & F.col("_is_email_valid")
    & F.col("subscription_date").isNotNull()
)

df_validated = (
    df_prepared
    .withColumn("_is_valid_record", valid_condition)
    .withColumn(
        "_rejection_reason",
        F.when(
            F.col("customer_id").isNull() | (F.length("customer_id") == 0),
            "Missing customer ID"
        )
        .when(
            F.col("first_name").isNull() | (F.length("first_name") == 0),
            "Missing first name"
        )
        .when(
            F.col("last_name").isNull() | (F.length("last_name") == 0),
            "Missing last name"
        )
        .when(~F.col("_is_email_valid"), "Invalid email")
        .when(F.col("subscription_date").isNull(), "Invalid subscription date")
    )
)

df_customer_silver = (
    df_validated
    .filter("_is_valid_record = true")
    .dropDuplicates(["customer_id"])
    .drop("_is_email_valid", "_is_valid_record", "_rejection_reason", "index")
)

df_customer_rejected = df_validated.filter("_is_valid_record = false")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4. Create Silver temporary views

# COMMAND ----------

df_customer_silver.createOrReplaceTempView("customer_silver_vw")
df_customer_rejected.createOrReplaceTempView("customer_rejected_vw")

display(spark.sql("""
SELECT customer_id, customer_full_name, city, country, email, subscription_date
FROM customer_silver_vw
ORDER BY customer_id
"""))

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5. Save Silver in Databricks Delta format

# COMMAND ----------

(
    df_customer_silver.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .save(silver_output_path)
)

(
    df_customer_rejected.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .save(silver_rejected_path)
)

print("Valid Silver records:", df_customer_silver.count())
print("Rejected records:", df_customer_rejected.count())
print("Silver path:", silver_output_path)

