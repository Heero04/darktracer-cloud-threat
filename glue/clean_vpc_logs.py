# This AWS Glue ETL job performs the following operations:
# 1. Initializes Spark and Glue contexts for data processing
# 2. Reads gzipped CSV log files from an S3 bucket with a nested folder structure (year/month/day/hour)
# 3. Validates if data exists in the source location
# 4. Prints basic data statistics like column names and row count
# 5. Writes the processed data to a target S3 bucket in CSV format with overwrite mode
# 6. Includes error handling and job status logging

import sys
from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# Initialize Glue contexts
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

print("Starting Glue job...")

try:
    # Optional: get the current year dynamically
    current_year = datetime.now().year
    # You can hardcode 2025 if needed
    # current_year = 2025

    # Path adjusted to match deep folders: /year/month/day/hour/file
    path = f"s3://darktracer-logs-dev/honeypot/{current_year}/*/*/*/honeypot-opencanary-logs.csv.gz"

    print(f"Reading from path: {path}")

    # Read CSV files
    df = spark.read \
        .option("header", "true") \
        .option("compression", "gzip") \
        .option("ignoreMissingFiles", "true") \
        .csv(path)

    # Check if DataFrame is empty
    if df.rdd.isEmpty():
        print("No data found at the specified path.")
        job.commit()
        sys.exit(0)

    print("Files read successfully!")
    print(f"Columns: {df.columns}")
    print(f"Row count: {df.count()}")
    df.show(5)

    # Write cleaned data back to another S3 path
    output_path = "s3://darktracer-training-bucket-dev/input/"
    print(f"Writing data to: {output_path}")

    df.write \
        .mode("overwrite") \
        .option("header", "true") \
        .csv(output_path)

except Exception as e:
    print("Error occurred:", str(e))
    raise e

# Finalize Glue job
job.commit()
print("Glue job completed.")
