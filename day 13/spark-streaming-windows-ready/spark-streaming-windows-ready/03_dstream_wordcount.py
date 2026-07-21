"""Legacy Spark Streaming DStream word-count demonstration."""

import os
import sys
from pathlib import Path

from pyspark import SparkConf, SparkContext
from pyspark.streaming import StreamingContext


PROJECT_ROOT = Path(__file__).resolve().parent
CHECKPOINT_PATH = (PROJECT_ROOT / "checkpoint" / "dstream_wordcount").as_posix()
HOST = "127.0.0.1"
PORT = 9999

os.environ["SPARK_LOCAL_IP"] = "127.0.0.1"
os.environ["PYSPARK_PYTHON"] = sys.executable
os.environ["PYSPARK_DRIVER_PYTHON"] = sys.executable

conf = SparkConf().setMaster("local[2]").setAppName("WindowsDStreamWordCount")
sc = SparkContext(conf=conf)
sc.setLogLevel("WARN")

ssc = StreamingContext(sc, 2)
ssc.checkpoint(CHECKPOINT_PATH)

lines = ssc.socketTextStream(HOST, PORT)
counts = (
    lines.flatMap(lambda line: line.split())
    .map(lambda word: (word.lower(), 1))
    .reduceByKey(lambda left, right: left + right)
)
counts.pprint()

print(f"Connecting to the Python sender at {HOST}:{PORT}")
print("Press Ctrl+C to stop.")

ssc.start()

try:
    ssc.awaitTermination()
except KeyboardInterrupt:
    print("\nStopping DStream...")
    ssc.stop(stopSparkContext=True, stopGraceFully=True)

