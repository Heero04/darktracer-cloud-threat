#----------------------------------------------------------
# Log Export Infrastructure Configuration
# Purpose: Sets up AWS infrastructure for exporting honeypot logs to S3
# Components: S3 bucket, Lambda function, IAM roles, EventBridge
# Last Updated: 2024
#----------------------------------------------------------

#----------------------------------------------------------
# Storage Configuration
# - S3 bucket for storing exported log files
#----------------------------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project_name}-logs-${terraform.workspace}"
  force_destroy = true
}

#----------------------------------------------------------
# IAM Configuration
# - Lambda execution role
# - Policy for CloudWatch logs access and S3 write permissions
#----------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-log-export-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "log-export-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = "${aws_s3_bucket.logs.arn}/*"
      }
    ]
  })
}

#----------------------------------------------------------
# Lambda Function Configuration
# - Honeypot log export function
# - Environment variables for S3 bucket configuration
#----------------------------------------------------------
resource "aws_lambda_function" "log_exporter" {
  filename         = "lambda_honeypot_to_csv_v3.zip"
  function_name    = "${var.project_name}-honeypot-log-export-${terraform.workspace}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_honeypot_to_csv.lambda_handler"
  runtime          = "python3.10"
  source_code_hash = filebase64sha256("lambda_honeypot_to_csv_v3.zip")

  environment {
    variables = {
      BUCKET_NAME   = aws_s3_bucket.logs.bucket
      BUCKET_PREFIX = "honeypot"
    }
  }
}

#----------------------------------------------------------
# EventBridge Configuration
# - Scheduled trigger for Lambda function
# - Event rule and target configuration
# - Lambda invocation permissions
#----------------------------------------------------------
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.project_name}-log-export-schedule-${terraform.workspace}"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "HoneypotLogExport"
  arn       = aws_lambda_function.log_exporter.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_exporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

resource "aws_iam_policy" "lambda_ec2_permissions" {
  name        = "${var.project_name}-lambda-ec2-access-${terraform.workspace}"
  description = "Allow Lambda to describe and modify security group rules"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ec2_permissions.arn
}
