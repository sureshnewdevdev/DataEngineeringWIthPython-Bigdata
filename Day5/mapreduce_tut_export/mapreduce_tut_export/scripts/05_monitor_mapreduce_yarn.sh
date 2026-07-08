#!/bin/bash
yarn application -list
yarn application -list -appStates FINISHED
yarn node -list
hdfs fsck /smartride/mapreduce/input/smartride_trip_words.txt -files -blocks -locations
echo "Open ResourceManager UI: http://localhost:8088"
