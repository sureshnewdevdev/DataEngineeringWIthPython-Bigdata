# Restaurant Spark Application

This project demonstrates Spark execution using a restaurant analogy and a practical PySpark RDD program.

## Restaurant-to-Spark mapping

| Restaurant concept | Spark concept |
|---|---|
| Restaurant | Spark application |
| Customer places an order | An action is called |
| One meal request | Job |
| Kitchen route plan | DAG |
| Preparation phases | Stages |
| Tray assigned to one cook | One task for one partition |
| Passing grouped ingredients | Shuffle |
| Cooks and kitchen stations | Executors |

## Scenario

The restaurant receives orders from multiple tables. The program:

1. Reads `data/orders.csv` using four requested partitions.
2. Removes the CSV header.
3. Keeps only `PAID` orders.
4. Maps each order to `(dish, quantity)`.
5. Runs `reduceByKey()` to total quantities for each dish.
6. Calls `collect()` to trigger execution.
7. Writes the collected result locally to `output/dish_totals.json`.

## Why a shuffle happens

The same dish can appear in different input partitions. `reduceByKey()` must move all values for a matching dish key to the same reduce partition. This movement is the shuffle and creates the boundary between Stage 0 and Stage 1.

## Expected execution

- Input partitions requested: **4**
- Stage 0: normally **4 tasks**
- Shuffle output partitions: **2**
- Stage 1: **2 tasks**
- Spark action: one final `collect()`

Spark may show extra implementation details depending on version and local file splitting, but the code explicitly requests these partition counts.

## Project structure

```text
restaurant-spark-application/
├── app.py
├── data/
│   └── orders.csv
├── output/
│   └── .gitkeep
├── EXPECTED_OUTPUT.json
├── requirements.txt
├── run_windows.bat
├── run_powershell.ps1
└── README.md
```

## Run with PowerShell

```powershell
cd restaurant-spark-application
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
python app.py --pause 60
```

The pause keeps Spark running so the Web UI can be inspected. Open the URL printed by the program, normally:

```text
http://localhost:4040
```

## Run with Command Prompt

```cmd
cd restaurant-spark-application
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python app.py --pause 60
```

Or double-click/run:

```cmd
run_windows.bat
```

## DAG and stage flow

```text
textFile (4 partitions)
        ↓ narrow
remove header
        ↓ narrow
filter PAID
        ↓ narrow
map to (dish, quantity)
        ↓
reduceByKey(numPartitions=2)
        ║ SHUFFLE BOUNDARY
        ↓
collect() ACTION
```

### Stage 0

- Four input partitions
- Four tasks
- Reads CSV rows
- Filters and maps rows
- Writes shuffle data grouped by destination partition

### Stage 1

- Two shuffle partitions
- Two tasks
- Reads shuffle data
- Adds quantities for each dish
- Returns final pairs to the driver

## What to inspect in Spark Web UI

- **Jobs:** the job triggered by `collect()`
- **Stages:** the two stages separated by the shuffle
- **Tasks:** task count, duration, input, and shuffle metrics
- **DAG visualization:** the operator chain and stage boundary
- **Executors:** local task execution and workload

## Expected totals

```text
Butter Naan                    10
Gulab Jamun                     6
Vegetable Biryani               6
Masala Dosa                     5
Paneer Butter Masala            4
```

## Windows warning note

Warnings about `winutils.exe`, `HADOOP_HOME`, or native Hadoop libraries are common in local Windows practice. They usually do not prevent this RDD application from running.

## Main learning point

`filter()`, `map()`, and `reduceByKey()` are lazy transformations. The actual distributed work begins only when `collect()` is called.
