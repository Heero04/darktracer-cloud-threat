# ===========================================================
#                     DarkTracer Cloud Threat
#                     S3 and IAM Configuration
# ===========================================================
# Description: Configures S3 bucket for model training data
#             and associated IAM policies for SageMaker access
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            Training Bucket Configuration
# ----------------------------------------------------------
# Purpose: Creates S3 bucket for storing training data
# Features:
# - Environment-specific naming
# - Force destroy enabled for cleanup
# - Standard tagging strategy
# ----------------------------------------------------------

resource "aws_s3_bucket" "training_bucket" {
  bucket = "${var.project_name}-training-bucket-${terraform.workspace}"

  # Enable force destroy for non-production environments
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-training-bucket-${terraform.workspace}"
    Environment = terraform.workspace
    Project     = var.project_name
  }
}

# ----------------------------------------------------------
#            Bucket Versioning Configuration
# ----------------------------------------------------------
# Purpose: Enables versioning for data protection
# Features:
# - Version history tracking
# - Accidental deletion protection
# - Data recovery capability
# ----------------------------------------------------------

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.training_bucket.id

  versioning_configuration {
    status = "Enabled"  # Maintains version history of all objects
  }
}

# ----------------------------------------------------------
#            Encryption Configuration
# ----------------------------------------------------------
# Purpose: Configures server-side encryption for data at rest
# Features:
# - AES-256 encryption
# - Automatic encryption of new objects
# - Compliance with security standards
# ----------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.training_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Industry-standard encryption
    }
  }
}

# ----------------------------------------------------------
#            SageMaker Access Policy
# ----------------------------------------------------------
# Purpose: Defines IAM policy for SageMaker bucket access
# Features:
# - Least privilege access
# - Specific bucket permissions
# - Environment separation
# - Access to training and logs
# ----------------------------------------------------------

resource "aws_iam_policy" "sagemaker_bucket_access" {
  name        = "${var.project_name}-sagemaker-s3-access-${terraform.workspace}"
  description = "Allow SageMaker to access training and logs buckets"

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
          # Training bucket permissions
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}",
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}/*",
          # Logs bucket permissions
          "arn:aws:s3:::${var.project_name}-logs-${terraform.workspace}",
          "arn:aws:s3:::${var.project_name}-logs-${terraform.workspace}/*"
        ]
      }
    ]
  })
}
