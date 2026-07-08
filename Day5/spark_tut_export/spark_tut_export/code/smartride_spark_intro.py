from pyspark.sql import SparkSession
from pyspark.sql.functions import sum, avg, count

spark = SparkSession.builder \
    .appName("SmartRideSparkIntro") \
    .master("local[*]") \
    .getOrCreate()

trips_df = spark.read.csv("data/trips.csv", header=True, inferSchema=True)

print("=== Input Trip Data ===")
trips_df.show()

print("=== Total Fare By City ===")
trips_df.groupBy("city").agg(sum("fare").alias("total_fare")).show()

print("=== Trip Count By City ===")
trips_df.groupBy("city").agg(count("*").alias("trip_count")).show()

print("=== Average Rating By Driver ===")
trips_df.groupBy("driver_id").agg(avg("rating").alias("avg_rating")).show()

spark.stop()
