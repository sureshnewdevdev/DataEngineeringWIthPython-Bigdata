"""Credential-free Structured Streaming social-feed demo for Windows."""

import os
import sys
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructField, StringType, StructType, TimestampType


PROJECT_ROOT = Path(__file__).resolve().parent
INPUT_PATH = (PROJECT_ROOT / "data" / "incoming_posts").as_posix()
CHECKPOINT_PATH = (PROJECT_ROOT / "checkpoint" / "social_demo").as_posix()

os.environ["SPARK_LOCAL_IP"] = "127.0.0.1"
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

spark = (
    SparkSession.builder
    .appName("WindowsSocialFileStreaming")
    .master("local[2]")
    .config("spark.sql.shuffle.partitions", "2")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

schema = StructType(
    [
        StructField("post_id", StringType(), False),
        StructField("text", StringType(), True),
        StructField("author_id", StringType(), True),
        StructField("created_at", TimestampType(), True),
    ]
)

posts = (
    spark.readStream
    .schema(schema)
    .option("maxFilesPerTrigger", 1)
    .json(INPUT_PATH)
)

words = (
    posts
    .filter(F.col("created_at").isNotNull())
    .withWatermark("created_at", "10 minutes")
    .select(
        "created_at",
        F.explode(
            F.split(
                F.lower(F.regexp_replace(F.col("text"), r"[^a-zA-Z0-9 ]", "")),
                r"\s+",
            )
        ).alias("word"),
    )
    .filter(F.length("word") >= 4)
)

counts = (
    words.groupBy(F.window("created_at", "5 minutes"), "word")
    .count()
    .orderBy(F.desc("count"), "word")
)

query = (
    counts.writeStream
    .format("console")
    .outputMode("complete")
    .trigger(processingTime="5 seconds")
    .option("truncate", False)
    .option("checkpointLocation", CHECKPOINT_PATH)
    .start()
)

print("Watching:", INPUT_PATH)
print("Run 04_social_feed_generator.py in another PowerShell terminal.")
print("Open http://localhost:4040 while this query runs.")
print("Press Ctrl+C to stop.")

try:
    query.awaitTermination()
except KeyboardInterrupt:
    print("\nStopping social stream...")
    query.stop()
finally:
    spark.stop()

