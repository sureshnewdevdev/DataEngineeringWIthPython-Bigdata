# Spark Streaming on Windows — Ready-to-Run Project

This project contains simple Windows 10/11 demos for:

1. Structured Streaming with the built-in rate source
2. Legacy DStreams using a Python socket sender
3. Structured Streaming using simulated social-post JSON files
4. Optional X/Twitter API → Kafka → Spark architecture

The first three demos do **not** require Hadoop, Kafka, Docker or X credentials.

## Recommended order

1. Run the rate-source demo.
2. Run the JSON social-feed demo.
3. Run the socket DStream demo.
4. Attempt Kafka/X only after the local demos work.

## Project contents

| File | Purpose |
|---|---|
| `01_rate_stream.py` | Simplest Structured Streaming test |
| `02_socket_sender.py` | Windows replacement for Linux `nc` |
| `03_dstream_wordcount.py` | Legacy DStream socket word count |
| `04_social_feed_generator.py` | Creates new JSON feed files atomically |
| `05_social_file_stream.py` | Windows Structured Streaming social trend demo |
| `06_x_to_kafka.py` | Optional authenticated X API producer |
| `07_kafka_stream_consumer.py` | Optional Spark Kafka consumer |
| `requirements.txt` | Python dependencies |
| `setup_windows.ps1` | Creates and configures a virtual environment |
| `data/incoming_posts/` | Watched JSON input folder |
| `checkpoint/` | Local demo checkpoints |
| `output/` | Optional generated output |

## Prerequisites

Install:

- 64-bit Java supported by your installed Spark version
- Python
- VS Code
- VS Code Python extension

Check in PowerShell:

```powershell
java -version
python --version
```

## Step 1 — Open the project

```powershell
cd "C:\path\to\spark-streaming-windows-ready"
code .
```

## Step 2 — Run the setup script

PowerShell may initially block scripts. If required, run this once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Then run:

```powershell
.\setup_windows.ps1
```

Activate later with:

```powershell
.\.venv\Scripts\Activate.ps1
```

## Demo 1 — Rate source

This is the best first test because it needs no external input.

```powershell
.\.venv\Scripts\Activate.ps1
python 01_rate_stream.py
```

Expected behavior: a new console table appears approximately every five seconds.

Stop with `Ctrl+C`.

## Demo 2 — JSON social feed

Open PowerShell terminal 1:

```powershell
.\.venv\Scripts\Activate.ps1
python 05_social_file_stream.py
```

Open PowerShell terminal 2:

```powershell
.\.venv\Scripts\Activate.ps1
python 04_social_feed_generator.py
```

The generator creates one new JSON batch every five seconds. The streaming program reads one new file per trigger and displays word counts.

Stop both terminals with `Ctrl+C`.

### Restart behavior

The checkpoint remembers processed files. To repeat the demo from the beginning, stop the query and run:

```powershell
Remove-Item -Recurse -Force .\checkpoint\social_demo
Remove-Item -Force .\data\incoming_posts\batch_*.json
```

Only remove these demo paths while the query is stopped.

## Demo 3 — DStream socket word count

Open PowerShell terminal 1:

```powershell
.\.venv\Scripts\Activate.ps1
python 02_socket_sender.py
```

Open PowerShell terminal 2:

```powershell
.\.venv\Scripts\Activate.ps1
python 03_dstream_wordcount.py
```

Return to terminal 1 and type:

```text
spark streaming spark
hadoop spark tez
```

Every two seconds, the DStream program prints word counts.

The socket example is for training only and does not provide production end-to-end fault tolerance.

## Optional Demo 4 — X/Twitter API to Kafka

This does **not** run until all of the following exist:

- X developer access and a valid bearer token
- Current X API access/credits
- Running Kafka broker
- `social-posts` Kafka topic
- Spark Kafka connector matching the installed Spark and Scala versions

Set the token only for the current PowerShell session:

```powershell
$env:X_BEARER_TOKEN = "YOUR_REAL_TOKEN"
python 06_x_to_kafka.py
```

Remove it after practice:

```powershell
Remove-Item Env:X_BEARER_TOKEN
```

Run the Spark consumer using a connector that exactly matches your Spark installation:

```powershell
spark-submit --packages YOUR_MATCHING_SPARK_KAFKA_PACKAGE 07_kafka_stream_consumer.py
```

Do not commit or share credentials.

## Windows notes

### winutils.exe warning

A local run may display a warning about `winutils.exe` or `HADOOP_HOME`. First test `01_rate_stream.py`. If it works, do not download random Hadoop binaries merely to hide a warning.

### Python interpreter mismatch

Each Spark program sets:

- `PYSPARK_PYTHON`
- `PYSPARK_DRIVER_PYTHON`
- `SPARK_LOCAL_IP`

Still ensure VS Code uses:

```text
.venv\Scripts\python.exe
```

### Port already in use

If port 9999 is busy:

```powershell
Get-NetTCPConnection -LocalPort 9999
```

Change `PORT` in both socket scripts to the same free port.

### No JSON output

- Start `05_social_file_stream.py` before the generator.
- Confirm new `batch_*.json` files appear.
- Do not continuously append to an already processed file.
- Delete the demo checkpoint only when intentionally restarting from zero.

## Spark UI

While a Spark application is active, open:

```text
http://localhost:4040
```

Inspect Jobs, Stages, SQL and Executors.

## Expected learning result

After completing the demos, you should be able to explain:

- Streaming and micro-batching
- DStreams as a sequence of RDDs
- Structured Streaming as an unbounded table
- Sources, transformations, sinks and checkpoints
- Event-time windows and watermarks
- X API → Kafka → Spark production workflow

