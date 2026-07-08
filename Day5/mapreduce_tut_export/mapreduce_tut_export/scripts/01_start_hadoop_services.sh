#!/bin/bash
start-dfs.sh
start-yarn.sh
echo "Checking Hadoop daemons..."
jps
echo "NameNode UI: http://localhost:9870"
echo "ResourceManager UI: http://localhost:8088"
