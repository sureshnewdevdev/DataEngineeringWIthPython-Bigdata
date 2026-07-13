from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Iterable, Tuple

from pyspark import SparkConf, SparkContext

OrderPair = Tuple[str, int]


def parse_order(line: str) -> OrderPair:
    """Convert one CSV row into (dish_name, quantity)."""
    parts = [part.strip() for part in line.split(",")]
    if len(parts) != 5:
        raise ValueError(f"Invalid order row: {line!r}")

    order_id, table_no, dish, quantity, status = parts
    if not order_id or not table_no or not dish:
        raise ValueError(f"Missing required value: {line!r}")

    return dish, int(quantity)


def format_lineage(debug_string: object) -> str:
    """Convert Spark's lineage output into readable text."""
    if isinstance(debug_string, bytes):
        return debug_string.decode("utf-8", errors="replace")
    return str(debug_string)


def print_analogy() -> None:
    print("\n" + "=" * 78)
    print("RESTAURANT -> APACHE SPARK EXECUTION ANALOGY")
    print("=" * 78)
    print("Restaurant                         -> Spark application")
    print("Customer places an order           -> Action is called")
    print("One meal request                    -> Job")
    print("Kitchen route plan                  -> DAG")
    print("Preparation phases                  -> Stages")
    print("Tray assigned to one cook           -> One task for one partition")
    print("Passing grouped ingredients         -> Shuffle")
    print("Cooks and kitchen stations          -> Executors")
    print("=" * 78)


def build_pipeline(sc: SparkContext, input_path: str):
    """Build the lazy RDD pipeline without triggering an action."""
    raw_orders = sc.textFile(input_path, minPartitions=4)

    header = "order_id,table_no,dish,quantity,status"
    main_rows = raw_orders.filter(lambda line: line.strip() != header)

    paid_orders = main_rows.filter(
        lambda line: line.split(",")[4].strip().upper() == "PAID"
    )

    dish_quantity_pairs = paid_orders.map(parse_order)

    # Wide transformation: matching dish keys are moved together.
    totals_by_dish = dish_quantity_pairs.reduceByKey(
        lambda left, right: left + right,
        numPartitions=2,
    )

    return totals_by_dish


def write_local_result(rows: Iterable[OrderPair], output_path: Path) -> None:
    """Write results locally after Spark finishes; this creates no Spark job."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    payload = [{"dish": dish, "total_quantity": qty} for dish, qty in rows]
    output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Restaurant order aggregation using a PySpark RDD."
    )
    parser.add_argument("--input", default="data/orders.csv")
    parser.add_argument("--output", default="output/dish_totals.json")
    parser.add_argument(
        "--pause",
        type=int,
        default=0,
        help="Keep Spark alive for N seconds to inspect the Web UI.",
    )
    args = parser.parse_args()

    conf = (
        SparkConf()
        .setAppName("RestaurantOrderSparkApplication")
        .setMaster("local[2]")
        .set("spark.ui.showConsoleProgress", "true")
    )

    sc = SparkContext.getOrCreate(conf=conf)
    sc.setLogLevel("WARN")
    sc.setJobGroup(
        "restaurant-order-job",
        "Count paid dish quantities across restaurant tables",
    )

    try:
        print_analogy()
        print(f"\nSpark Web UI: {sc.uiWebUrl or 'http://localhost:4040'}")
        print("Local executor threads: 2")

        pipeline = build_pipeline(sc, args.input)

        print("\nLAZY PIPELINE CREATED")
        print("- No aggregation has run yet.")
        print("- Requested input partitions: 4")
        print("- Requested shuffle output partitions: 2")
        print("- Expected Stage 0: 4 tasks for read/filter/map + shuffle write")
        print("- Expected Stage 1: 2 tasks for shuffle read + reduction")

        print("\nRDD LINEAGE / DAG")
        print(format_lineage(pipeline.toDebugString()))

        print("\nACTION CALLED: collect()")
        print("- Spark creates the job.")
        print("- The DAG scheduler splits it at the reduceByKey shuffle.")
        print("- Tasks are submitted to executor threads.")

        # The only Spark action in the application.
        collected = pipeline.collect()
        sorted_results = sorted(collected, key=lambda item: (-item[1], item[0]))

        print("\nFINAL DISH TOTALS")
        print("-" * 46)
        for dish, quantity in sorted_results:
            print(f"{dish:<30} {quantity:>5}")
        print("-" * 46)

        write_local_result(sorted_results, Path(args.output))
        print(f"\nLocal result written to: {args.output}")

        if args.pause > 0:
            print(
                f"\nSpark remains active for {args.pause} seconds. "
                f"Open {sc.uiWebUrl or 'http://localhost:4040'} to inspect it."
            )
            time.sleep(args.pause)
    finally:
        sc.stop()


if __name__ == "__main__":
    main()
