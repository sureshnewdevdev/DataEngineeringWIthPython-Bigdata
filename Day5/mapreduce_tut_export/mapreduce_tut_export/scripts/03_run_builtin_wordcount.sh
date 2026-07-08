#!/bin/bash
hdfs dfs -rm -r -f /smartride/mapreduce/output_builtin
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-*.jar \
  wordcount \
  /smartride/mapreduce/input \
  /smartride/mapreduce/output_builtin
echo "Output:"
hdfs dfs -cat /smartride/mapreduce/output_builtin/part-r-00000
