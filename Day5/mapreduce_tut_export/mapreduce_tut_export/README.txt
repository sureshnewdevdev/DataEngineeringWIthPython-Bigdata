# MapReduce TUT Export

This package contains a complete classroom-style tutorial for:

- Introduction to MapReduce
- Mapper Class
- Reducer Class
- Driver Program
- Data flow in MapReduce
- Difference between HDFS Blocks and InputSplit
- Role of RecordReader
- Implementation of MapReduce WordCount
- Real-time SmartRide/Uber-style example
- Hadoop working diagrams
- Practice quiz, timed exam and progress tracker

## Files

- `index.html` - TUT-style tutorial
- `sample-data/smartride_trip_words.txt` - WordCount input
- `sample-data/smartride_trip_logs.csv` - Real-time style trip log sample
- `java-wordcount/` - Java MapReduce WordCount Maven project
- `scripts/` - Hadoop lab scripts
- `notes/trainer_activity_plan.md` - Trainer activity plan

## How to Use

1. Open `index.html` in a browser.
2. Run scripts in a Hadoop environment.
3. Use `03_run_builtin_wordcount.sh` for quick demo.
4. Use `04_build_and_run_custom_wordcount.sh` for custom Java MapReduce demo.

## Prerequisites

- Hadoop installed and configured
- HDFS and YARN running
- Java JDK
- Maven
