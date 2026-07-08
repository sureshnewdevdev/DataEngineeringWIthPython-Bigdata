#!/bin/bash
hdfs dfs -mkdir -p /smartride/mapreduce/input
hdfs dfs -put -f sample-data/smartride_trip_words.txt /smartride/mapreduce/input/
echo "Input files in HDFS:"
hdfs dfs -ls /smartride/mapreduce/input
hdfs dfs -cat /smartride/mapreduce/input/smartride_trip_words.txt
