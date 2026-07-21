"""Optional Structured Streaming consumer for X JSON stored in Kafka."""

import os
import sys
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructField, StringType, StructType


PROJECT_ROOT = Path(__file__).resolve().parent
CHECKPOINT_PATH = (PROJECT_ROOT / "checkpoint" / "x_kafka").as_posix()

os.environ["SPARK_LOCAL_IP"] = "127.0.0.1"
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

spark = (
    SparkSession.builder
    .appName("WindowsXKafkaStreaming")
    .master("local[2]")
    .config("spark.sql.shuffle.partitions", "2")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

post_schema = StructType(
    [
        StructField("id", StringType()),
        StructField("text", StringType()),
        StructField("author_id", StringType()),
        StructField("created_at", StringType()),
        StructField("lang", StringType()),
    ]
)
envelope_schema = StructType([StructField("data", post_schema)])

raw = (
    spark.readStream
    .format("kafka")
    .option("kafka.bootstrap.servers", "localhost:9092")
    .option("subscribe", "social-posts")
    .option("startingOffsets", "latest")
    .load()
)

posts = (
    raw.select(
        F.from_json(F.col("value").cast("string"), envelope_schema).alias("json")
    )
    .select("json.data.*")
    .withColumn("created_at", F.to_timestamp("created_at"))
    .filter((F.col("lang") == "en") & F.col("created_at").isNotNull())
)

trends = (
    posts.withWatermark("created_at", "10 minutes")
    .groupBy(F.window("created_at", "5 minutes"))
    .agg(F.count("*").alias("post_count"))
)

query = (
    trends.writeStream
    .format("console")
    .outputMode("update")
    .option("truncate", False)
    .option("checkpointLocation", CHECKPOINT_PATH)
    .start()
)

try:
    query.awaitTermination()
except KeyboardInterrupt:
    query.stop()
finally:
    spark.stop()

