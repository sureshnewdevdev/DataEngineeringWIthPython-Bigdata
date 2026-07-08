from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SmartRideSparkSQL") \
    .master("local[*]") \
    .getOrCreate()

trips_df = spark.read.csv("data/trips.csv", header=True, inferSchema=True)
trips_df.createOrReplaceTempView("trips")

spark.sql("""
SELECT city, COUNT(*) AS trip_count, SUM(fare) AS total_fare, ROUND(AVG(rating), 2) AS avg_rating
FROM trips
GROUP BY city
ORDER BY total_fare DESC
""").show()

spark.stop()
