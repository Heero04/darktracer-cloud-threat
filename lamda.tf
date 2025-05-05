# ===========================================================
#                 Lambda Configuration File
#          Threat Analysis and Log Processing
# ===========================================================
# Description: Defines Lambda functions and IAM roles for
#             threat analysis and log processing
# Last Updated: YYYY-MM-DD
# ===========================================================

# ----------------------------------------------------------
#            Lambda Execution Role Configuration
# ----------------------------------------------------------
# Purpose: Define base IAM role for Lambda execution
# ----------------------------------------------------------

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach basic Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Add this to your lambda.tf or iam.tf
resource "aws_iam_role_policy" "lambda_ec2_policy" {
  name = "${var.project_name}-lambda-ec2-policy-${terraform.workspace}"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------
#            Lambda IAM Policy Configuration
# ----------------------------------------------------------
# Purpose: Grant Lambda permissions for:
# - CloudWatch Logs access
# - S3 read/write access
# - DynamoDB write access
# - SageMaker endpoint invocation
# ----------------------------------------------------------

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${terraform.workspace}"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          aws_s3_bucket.log_archive.arn,
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "sagemaker:InvokeEndpoint"
        ],
        Resource = "*" # TODO: Replace with SageMaker endpoint ARN if needed
      }
    ]
  })
}



# ----------------------------------------------------------
#            Threat Analyzer Configuration
# ----------------------------------------------------------
# Purpose: Configure Lambda function for threat analysis
# Includes: Function definition and environment variables
# ----------------------------------------------------------

data "aws_region" "current" {}

resource "aws_lambda_function" "lambda_threat_analyzer" {
  filename      = "lambda_threat_analyzer.zip"
  function_name = "${var.project_name}-threat-analyzer-${terraform.workspace}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_threat_analyzer.handler" # Changed to match the function name
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      PROJECT_NAME            = var.project_name
      ENV                     = terraform.workspace
      WAF_IP_SET_ID           = aws_wafv2_ip_set.blocked_ips.id
      SNS_TOPIC_ARN           = aws_sns_topic.threat_alerts.id
      SECURITY_GROUP_ID       = aws_security_group.honeypot_sg.id
      THREAT_THRESHOLD        = "0.8"
      SAGEMAKER_ENDPOINT_NAME = "darktracer-threat-endpoint"
    }
  }
}


# ----------------------------------------------------------
#            Lambda Permissions Configuration
# ----------------------------------------------------------
# Purpose: Configure S3 and Honeypot trigger permissions
# ----------------------------------------------------------

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_threat_analyzer.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.log_archive.arn
}

resource "aws_lambda_permission" "allow_honeypot" {
  statement_id  = "AllowHoneypotInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_threat_analyzer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.log_archive.arn
}

# ===========================================================
#                     Quick Reference
# ===========================================================
# Components:
# 1. Lambda Execution Role & Policies
# 2. Threat Analyzer Function
# 3. S3 & Honeypot Permissions
# 4. Event Notifications (disabled)
#
# ===========================================================

#----------------------------------------------------------
# Lambda Function Configuration for Log Summarization
# Purpose: Processes and summarizes threat logs using Bedrock
# Components: Lambda function with Bedrock integration
# Last Updated: 2024
#----------------------------------------------------------

resource "aws_lambda_function" "summarize_logs" {
  # Basic Lambda Configuration
  function_name = "${var.project_name}-summarize-threats-${terraform.workspace}"
  role          = aws_iam_role.bedrock_lambda_role.arn
  handler       = "chatbot_lambda.lambda_handler"

  # Runtime Configuration
  runtime     = "python3.12" # Latest stable Python runtime
  timeout     = 30           # Maximum execution time in seconds
  memory_size = 256          # Allocated memory in MB

  # Deployment Package
  filename = "chatbot_lambda.zip" # Local path to deployment package

  #----------------------------------------------------------
  # Environment Variables
  # - TRAINING_LOG_BUCKET: References existing S3 bucket from s3.tf
  # - MODEL_ID: Bedrock model identifier for text processing
  #----------------------------------------------------------
  environment {
    variables = {
      TRAINING_LOG_BUCKET = aws_s3_bucket.training_bucket.id # Reference to existing training bucket
      MODEL_ID            = "anthropic.claude-v2"            # Bedrock model identifier
    }
  }
}

# ===========================================================
#                     Athena Unload Lambda Function
# Purpose: Unloads Athena query results to S3 training bucket
# Components: Lambda function with Athena integration
# ===========================================================

# Lambda Function
resource "aws_lambda_function" "athena_unload" {
  filename      = "lambda_athena_unload_v10.zip"
  function_name = "${var.project_name}-athena-unload-${terraform.workspace}"
  role          = aws_iam_role.athena_lambda_role.arn
  handler       = "lambda_athena_unload.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300
  memory_size   = 256

  environment {
    variables = {
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = terraform.workspace
      ATHENA_TABLE = "honeypot_logs"
    }
  }
}

# CloudWatch Logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
