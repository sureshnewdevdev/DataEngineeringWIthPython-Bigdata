# Databricks notebook source
# Databricks notebook: customer_Bronze

storage_account_name = "newstoreforsession"
container_name = "datasource"

# Read the Azure Storage access key from Databricks Secrets
storage_account_key = dbutils.secrets.get(
    scope="azure-storage",
    key="XXXXXXX"
)

# Configure Spark to access Azure Blob Storage
spark.conf.set(
    f"fs.azure.account.key.{storage_account_name}.blob.core.windows.net",
    storage_account_key
)

print("Azure Storage configuration completed.")

# COMMAND ----------

storage_account_name = "newstoreforsession"
container_name = "datasource"

source_file_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "customers-100.csv"
)

bronze_output_path = (
    f"wasbs://{container_name}@{storage_account_name}.blob.core.windows.net/"
    "bronze/customer"
)

print("Source:", source_file_path)
print("Output:", bronze_output_path)

# COMMAND ----------

df_customer = (
    spark.read
    .format("csv")
    .option("header", "true")
    .option("inferSchema", "true")
    .load(source_file_path)
)

display(df_customer)

# COMMAND ----------

print("Total customer records:", df_customer.count())

df_customer.printSchema()

# COMMAND ----------

from pyspark.sql import functions as F

df_customer = (
    df_customer
    .withColumn("_source_file", F.input_file_name())
    .withColumn("_ingestion_timestamp", F.current_timestamp())
)

display(df_customer)

# COMMAND ----------

(
    df_customer.write
               .format("csv")
               .mode("overwrite")
               .option("header", "true")
               .save(bronze_output_path)
)

print("Customer Bronze data written successfully.")
print("Output location:", bronze_output_path)

# COMMAND ----------

df_customer_check = (
    spark.read
         .format("csv")
         .option("header", "true")
         .option("inferSchema", "true")
         .load(bronze_output_path)
)

display(df_customer_check)

print("Written record count:", df_customer_check.count())