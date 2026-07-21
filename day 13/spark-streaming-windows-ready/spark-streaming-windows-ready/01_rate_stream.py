"""Simplest Windows Structured Streaming demonstration."""

import os
import sys
from pathlib import Path

from pyspark.sql import SparkSession
from pyspark.sql import functions as F


PROJECT_ROOT = Path(__file__).resolve().parent
CHECKPOINT_PATH = (PROJECT_ROOT / "checkpoint" / "rate_demo").as_posix()

os.environ["SPARK_LOCAL_IP"] = "127.0.0.1"
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

spark = (
    SparkSession.builder
    .appName("WindowsRateStreamingDemo")
    .master("local[2]")
    .config("spark.sql.shuffle.partitions", "2")
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

events = (
    spark.readStream
    .format("rate")
    .option("rowsPerSecond", 5)
    .load()
)

result = events.withColumn(
    "event_type",
    F.when(F.col("value") % 2 == 0, "EVEN").otherwise("ODD"),
)

query = (
    result.writeStream
    .format("console")
    .outputMode("append")
    .trigger(processingTime="5 seconds")
    .option("truncate", False)
    .option("checkpointLocation", CHECKPOINT_PATH)
    .start()
)

print("Streaming started. Open http://localhost:4040 while it runs.")
print("Press Ctrl+C to stop.")

try:
    query.awaitTermination()
except KeyboardInterrupt:
    print("\nStopping streaming query...")
    query.stop()
finally:
    spark.stop()

