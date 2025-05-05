import boto3
import os
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ====================
# Configurations
# ====================
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'darktracer')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

ATHENA_DATABASE = f"{PROJECT_NAME}_clean_logs_{ENVIRONMENT}"
ATHENA_TABLE = os.environ.get('ATHENA_TABLE', 'honeypot_logs')

ATHENA_OUTPUT = f"s3://{PROJECT_NAME}-training-bucket-{ENVIRONMENT}/athena-results/"
UNLOAD_TARGET = f"s3://{PROJECT_NAME}-training-bucket-{ENVIRONMENT}/input/"

athena = boto3.client('athena')
s3 = boto3.client('s3')

# ====================
# Helper Functions
# ====================

def run_query(query):
    try:
        response = athena.start_query_execution(
            QueryString=query,
            QueryExecutionContext={'Database': ATHENA_DATABASE},
            ResultConfiguration={'OutputLocation': ATHENA_OUTPUT}
        )
        return response['QueryExecutionId']
    except Exception as e:
        logger.error(f"Error executing query: {str(e)}")
        raise

def wait_for_query(execution_id, timeout=300):
    start_time = time.time()
    while True:
        if time.time() - start_time > timeout:
            raise Exception("Query timeout exceeded")

        status = athena.get_query_execution(QueryExecutionId=execution_id)
        state = status['QueryExecution']['Status']['State']

        if state == 'FAILED':
            reason = status['QueryExecution']['Status'].get('StateChangeReason', 'No reason provided')
            raise Exception(f"Query failed: {reason}")
        
        if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            return state

        time.sleep(1)

def get_query_results(execution_id):
    try:
        result = athena.get_query_results(QueryExecutionId=execution_id)
        return result['ResultSet']['Rows']
    except Exception as e:
        logger.error(f"Error getting query results: {str(e)}")
        raise

# --- CHANGED: Replaced write_header_file with combine_header_and_data ---

def combine_header_and_data(bucket, prefix, header, output_filename='final_output.csv'):
    try:
        logger.info(f"Combining header and data in bucket {bucket}, prefix {prefix}")

        retries = 5  # Try 5 times
        data_files = []

        for attempt in range(retries):
            response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
            data_files = [obj['Key'] for obj in response.get('Contents', []) if obj['Key'].endswith('_0')]

            if data_files:
                break  # Found data files, no need to retry
            else:
                logger.warning(f"No data files found, retrying... ({attempt+1}/{retries})")
                time.sleep(2)  # wait 2 seconds and retry

        if not data_files:
            raise Exception("No data files found after retries")

        first_data_file_key = data_files[0]
        logger.info(f"Using first data file: {first_data_file_key}")

        data_obj = s3.get_object(Bucket=bucket, Key=first_data_file_key)
        data_body = data_obj['Body'].read()

        combined_data = header.encode('utf-8') + data_body

        final_key = prefix + output_filename
        s3.put_object(Bucket=bucket, Key=final_key, Body=combined_data)

        logger.info(f"Written combined file to {final_key}")

    except Exception as e:
        logger.error(f"Error combining header and data: {str(e)}")
        raise


# --- END CHANGED ---

# ====================
# Lambda Handler
# ====================

def lambda_handler(event, context):
    try:
        # 1. Run COUNT(*) query
        count_query = f"SELECT COUNT(*) AS total FROM {ATHENA_TABLE}"
        exec_id = run_query(count_query)
        wait_for_query(exec_id)
        rows = get_query_results(exec_id)
        count = int(rows[1]['Data'][0]['VarCharValue'])  # rows[0] = column names

        logger.info(f"Total rows to unload: {count}")

        if count > 0:
            # 2. Run UNLOAD
            unload_query = f"""
                UNLOAD (
                    SELECT 
                        CAST(utc_time AS VARCHAR) as utc_time,
                        src_host,
                        CAST(src_port AS VARCHAR) as src_port,
                        dst_host,
                        CAST(dst_port AS VARCHAR) as dst_port,
                        CAST(logtype AS VARCHAR) as logtype,
                        node_id,
                        username,
                        password
                    FROM {ATHENA_TABLE}
                )
                TO '{UNLOAD_TARGET}'
                WITH (format = 'CSV')
            """

            logger.info("Starting UNLOAD operation")
            unload_id = run_query(unload_query)

            if wait_for_query(unload_id) != 'SUCCEEDED':
                raise Exception("UNLOAD query failed")

            logger.info("Successfully unloaded data")

            # --- ADD THIS ---
            logger.info("Waiting 5 seconds for S3 to receive unload files...")
            time.sleep(5)
            # --- END ADD ---
            
            # --- CHANGED: Use combine_header_and_data instead of writing separate headers ---
            bucket = f"{PROJECT_NAME}-training-bucket-{ENVIRONMENT}"
            prefix = "input/"
            header_line = "utc_time,src_host,src_port,dst_host,dst_port,logtype,node_id,username,password\n"
            combine_header_and_data(bucket, prefix, header_line)
            # --- END CHANGED ---

        else:
            logger.info("No data to unload")

        return {
            'statusCode': 200,
            'body': f'Successfully processed {count} rows',
            'unloadLocation': UNLOAD_TARGET
        }

    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error processing request: {str(e)}'
        }
