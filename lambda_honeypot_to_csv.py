import boto3
import gzip
import csv
import json
import os
from datetime import datetime, timedelta
from io import BytesIO, StringIO

logs = boto3.client("logs")
s3 = boto3.client("s3")

LOG_GROUP = "/darktracer/honeypot/opencanary"
BUCKET = os.environ.get("BUCKET_NAME", "darktracer-logs-dev")
PREFIX = os.environ.get("BUCKET_PREFIX", "honeypot")

def lambda_handler(event=None, context=None):
    now = datetime.utcnow()
    end_time = int(now.timestamp() * 1000)
    start_time = int((now - timedelta(minutes=30)).timestamp() * 1000)

    print(f"📅 Fetching logs from {LOG_GROUP} from {start_time} to {end_time}")

    response = logs.filter_log_events(
        logGroupName=LOG_GROUP,
        startTime=start_time,
        endTime=end_time,
        limit=10000
    )

    events = response.get("events", [])

    if not events:
        print("⚠️ No logs found in time window.")
        return

    # Prepare CSV with new columns
    csv_buffer = StringIO()
    writer = csv.writer(csv_buffer)
    writer.writerow([
        "utc_time",
        "src_host",
        "src_port",
        "dst_host",
        "dst_port",
        "logtype",
        "node_id",
        "username",
        "password"
    ])

    for event in events:
        try:
            # Parse the JSON message
            log_data = json.loads(event["message"])
            
            # Extract values, using get() to handle missing fields safely
            writer.writerow([
                log_data.get("utc_time", ""),
                log_data.get("src_host", ""),
                log_data.get("src_port", ""),
                log_data.get("dst_host", ""),
                log_data.get("dst_port", ""),
                log_data.get("logtype", ""),
                log_data.get("node_id", ""),
                log_data.get("logdata", {}).get("USERNAME", ""),
                log_data.get("logdata", {}).get("PASSWORD", "")
            ])
        except json.JSONDecodeError:
            print(f"⚠️ Failed to parse JSON from log: {event['message']}")
            continue

    # Compress CSV
    gz_buffer = BytesIO()
    with gzip.GzipFile(mode="w", fileobj=gz_buffer) as gz_file:
        gz_file.write(csv_buffer.getvalue().encode("utf-8"))

    # Define dynamic S3 path
    time_path = now.strftime("%Y/%m/%d/%H")
    key = f"{PREFIX}/{time_path}/honeypot-opencanary-logs.csv.gz"

    s3.put_object(Bucket=BUCKET, Key=key, Body=gz_buffer.getvalue())
    print(f"✅ Uploaded {len(events)} log events to s3://{BUCKET}/{key}")
