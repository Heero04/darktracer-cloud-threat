import boto3, json, os

# Initialize clients
s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime")

def lambda_handler(event, context):
    try:
        # Accept user question from event (JSON or query)
        question = event.get("question") or json.loads(event.get("body", "{}")).get("question", "")
        if not question:
            return {"statusCode": 400, "body": json.dumps({"error": "Missing 'question' in request"})}

        # Pull logs from S3
        bucket = os.environ["CLEAN_LOG_BUCKET"]
        s3_key = os.environ["LOG_KEY"]  # You can make this dynamic later

        log_data = s3.get_object(Bucket=bucket, Key=s3_key)['Body'].read().decode("utf-8")

        # Prompt for Claude-style models
        prompt = f"\n\nHuman: Given the following logs:\n{log_data}\n\n{question}\n\nAssistant:"

        # Call Bedrock (e.g., Claude v2)
        response = bedrock.invoke_model(
            modelId=os.environ["MODEL_ID"],
            body=json.dumps({
                "prompt": prompt,
                "max_tokens_to_sample": 400,
                "temperature": 0.5
            }),
            contentType="application/json",
            accept="application/json"
        )

        result = json.loads(response["body"].read())
        summary = result.get("completion", "[No output from model]")

        return {
            "statusCode": 200,
            "body": json.dumps({"answer": summary})
        }

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
