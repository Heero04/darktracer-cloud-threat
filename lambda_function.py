# Import required AWS SDK and JSON library
import json
import boto3

# AWS Lambda handler function that processes S3 events
def lambda_handler(event, context):
    # Log the incoming event for debugging
    print("Event received:", json.dumps(event))

    # Extract S3 bucket and key information from the event
    record = event['Records'][0]
    bucket = record['s3']['bucket']['name']
    key    = record['s3']['object']['key']

    # Initialize S3 client and retrieve object
    s3 = boto3.client('s3')
    response = s3.get_object(Bucket=bucket, Key=key)
    body = response['Body'].read()

    # Print first 500 bytes of file content for debugging
    print("File content:", body[:500])  # Truncated preview

    # You'd invoke SageMaker and write to DynamoDB here next

    # Return success response
    return {
        'statusCode': 200,
        'body': 'Processed'
    }
