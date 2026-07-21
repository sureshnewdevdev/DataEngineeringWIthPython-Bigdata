"""Optional X API v2 filtered-stream producer.

Requires:
- X developer access and X_BEARER_TOKEN
- Running Kafka at localhost:9092
- Existing social-posts topic
"""

import os
import time

import requests
from kafka import KafkaProducer


TOKEN = os.environ.get("X_BEARER_TOKEN")
if not TOKEN:
    raise RuntimeError(
        "X_BEARER_TOKEN is missing. Set it temporarily in PowerShell before running."
    )

producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    value_serializer=lambda value: value.encode("utf-8"),
    retries=5,
)

url = (
    "https://api.x.com/2/tweets/search/stream"
    "?tweet.fields=created_at,lang,author_id"
)
headers = {"Authorization": f"Bearer {TOKEN}"}

print("Connecting to the X filtered stream. Press Ctrl+C to stop.")

backoff_seconds = 5
while True:
    try:
        with requests.get(
            url,
            headers=headers,
            stream=True,
            timeout=(10, 90),
        ) as response:
            response.raise_for_status()
            backoff_seconds = 5

            for line in response.iter_lines(decode_unicode=True):
                if line:
                    producer.send("social-posts", line)
    except KeyboardInterrupt:
        print("\nStopping X producer...")
        producer.flush()
        producer.close()
        break
    except requests.RequestException as error:
        print("Stream error:", error)
        print(f"Retrying in {backoff_seconds} seconds...")
        time.sleep(backoff_seconds)
        backoff_seconds = min(backoff_seconds * 2, 120)

