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
