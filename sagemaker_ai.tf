# ===========================================================
#                     DarkTracer Cloud Threat
#                     SageMaker IAM Configuration
# ===========================================================
# Description: Configures IAM roles and policies for SageMaker
#             execution, including ECR access, S3 permissions,
#             and CloudWatch logging capabilities
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            SageMaker Execution Role
# ----------------------------------------------------------
# Purpose: Creates main IAM role for SageMaker execution
# Features:
# - Trust relationship with SageMaker service
# - Environment-specific naming
# - AssumeRole permissions
# ----------------------------------------------------------

resource "aws_iam_role" "sagemaker_execution" {
  name = "${var.project_name}-sagemaker-exec-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# ----------------------------------------------------------
#            ECR Access Policy
# ----------------------------------------------------------
# Purpose: Enables SageMaker to pull container images from ECR
# Features:
# - Image layer access
# - Authentication permissions
# - Repository access control
# - Region-specific configuration
# ----------------------------------------------------------

resource "aws_iam_role_policy" "sagemaker_ecr" {
  name = "sagemaker-ecr-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",     # Get image layer download URLs
          "ecr:BatchGetImage",              # Retrieve container images
          "ecr:BatchCheckLayerAvailability" # Verify image layer availability
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"       # Authenticate with ECR
        ]
        Resource = ["*"]                    # Required for authentication
      }
    ]
  })
}

# ----------------------------------------------------------
#            S3 Access Policy
# ----------------------------------------------------------
# Purpose: Provides access to S3 for model artifacts
# Features:
# - Read/write permissions
# - Bucket listing capability
# - Specific bucket access
# - Least privilege access
# ----------------------------------------------------------

resource "aws_iam_role_policy" "sagemaker_s3" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",    # Read objects
          "s3:PutObject",    # Write objects
          "s3:ListBucket"    # List bucket contents
        ]
        Resource = [
          "${aws_s3_bucket.training_bucket.arn}",        # Bucket-level access
          "${aws_s3_bucket.training_bucket.arn}/*"       # Object-level access
        ]
      }
    ]
  })
}

# ----------------------------------------------------------
#            CloudWatch Logging Policy
# ----------------------------------------------------------
# Purpose: Enables CloudWatch logging and metrics
# Features:
# - Metric publishing
# - Log stream management
# - Log group creation
# - Stream description access
# ----------------------------------------------------------

resource "aws_iam_role_policy" "sagemaker_cloudwatch" {
  name = "sagemaker-cloudwatch-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",      # Publish metrics
          "logs:CreateLogStream",          # Create new log streams
          "logs:PutLogEvents",             # Write log events
          "logs:CreateLogGroup",           # Create new log groups
          "logs:DescribeLogStreams"        # View log stream metadata
        ]
        Resource = "*"                     # Required for CloudWatch functionality
      }
    ]
  })
}
