#!/bin/bash
cd java-wordcount
mvn clean package
cd ..
hdfs dfs -rm -r -f /smartride/mapreduce/output_custom
hadoop jar java-wordcount/target/mapreduce-wordcount-1.0.jar \
  com.smartride.mapreduce.SmartRideWordCount \
  /smartride/mapreduce/input \
  /smartride/mapreduce/output_custom
echo "Output:"
hdfs dfs -cat /smartride/mapreduce/output_custom/part-r-00000
