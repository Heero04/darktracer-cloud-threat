#----------------------------------------
# IAM ROLES AND POLICIES
#----------------------------------------

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

#----------------------------------------
# MODEL
#----------------------------------------




#----------------------------------------
# IAM ROLES AND POLICIES
#----------------------------------------

# Add ECR pull permissions
resource "aws_iam_role_policy" "sagemaker_ecr" {
  name = "sagemaker-ecr-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Add S3 access for model artifacts
resource "aws_iam_role_policy" "sagemaker_s3" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.training_bucket.arn}",
          "${aws_s3_bucket.training_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Add CloudWatch logging permissions
resource "aws_iam_role_policy" "sagemaker_cloudwatch" {
  name = "sagemaker-cloudwatch-access"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

#----------------------------------------

