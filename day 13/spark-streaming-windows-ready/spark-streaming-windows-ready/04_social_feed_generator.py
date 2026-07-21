"""Generate social-post JSON files atomically for the Windows file-stream demo."""

import json
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent
INPUT_DIR = PROJECT_ROOT / "data" / "incoming_posts"
INPUT_DIR.mkdir(parents=True, exist_ok=True)

POST_TEXTS = [
    "Learning Spark structured streaming today",
    "PySpark makes data engineering practical",
    "Spark streaming with event time windows",
    "Kafka and Spark build reliable pipelines",
    "Structured streaming checkpoint recovery",
    "Watermarks handle late social events",
    "Spark SQL processes live retail feeds",
    "Data engineers monitor streaming latency",
    "Micro batches update dashboards quickly",
    "Python and Spark power analytics",
    "Retail teams study product trends",
    "Streaming systems need durable checkpoints",
]

base_time = datetime.now(timezone.utc).replace(microsecond=0)

print("Generating one JSON batch every five seconds.")
print("Press Ctrl+C to stop.")

try:
    for batch_number in range(1, 7):
        records = []
        for offset in range(2):
            index = (batch_number - 1) * 2 + offset
            records.append(
                {
                    "post_id": f"p{index + 101}",
                    "text": POST_TEXTS[index],
                    "author_id": f"u{(index % 5) + 1}",
                    "created_at": (
                        base_time + timedelta(seconds=index * 15)
                    ).isoformat().replace("+00:00", "Z"),
                }
            )

        temporary_path = INPUT_DIR / f".batch_{batch_number:02d}.tmp"
        final_path = INPUT_DIR / f"batch_{batch_number:02d}.json"

        with temporary_path.open("w", encoding="utf-8") as file:
            for record in records:
                file.write(json.dumps(record) + "\n")

        temporary_path.replace(final_path)
        print("Created:", final_path.name)
        time.sleep(5)
except KeyboardInterrupt:
    print("\nGenerator stopped.")

