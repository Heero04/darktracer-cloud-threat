# ===========================================================
#                     DarkTracer Cloud Threat
#                     CloudTrail Configuration
# ===========================================================
# Description: Configures AWS CloudTrail and associated S3 bucket
#             for comprehensive logging and audit capabilities
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#                S3 Bucket Configuration
# ----------------------------------------------------------
# Purpose: Creates and configures S3 bucket for CloudTrail logs
# Includes:
# - Bucket creation with force destroy enabled
# - Lifecycle rules for log retention
# - Server-side encryption
# - Public access blocking
# ----------------------------------------------------------

# S3 bucket to store CloudTrail logs with force_destroy enabled
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.project_name}-cloudtrail-logs-${terraform.workspace}"
  force_destroy = true
}

# Lifecycle configuration for log retention
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs_lifecycle" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "expire-cloudtrail-logs-after-1-day"
    status = "Enabled"

    expiration {
      days = 1
    }

    filter {
      prefix = "" # Empty string means it applies to all objects
    }
  }
}

# ----------------------------------------------------------
#            Security Configuration for S3 Bucket
# ----------------------------------------------------------
# Purpose: Implements security measures for the CloudTrail bucket
# Includes:
# - Server-side encryption configuration
# - Bucket policy for CloudTrail access
# - Public access blocking
# ----------------------------------------------------------

# Enable default server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 bucket policy for CloudTrail permissions
resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs_block" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ----------------------------------------------------------
#            CloudTrail Configuration
# ----------------------------------------------------------
# Purpose: Sets up CloudTrail for comprehensive API logging
# Features:
# - Multi-region trail
# - Global service event logging
# - Log file validation
# - Management event logging
# ----------------------------------------------------------

# CloudTrail configuration
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail-${terraform.workspace}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-trail-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Supporting Resources
# ----------------------------------------------------------

# Get the current AWS account ID
data "aws_caller_identity" "current" {}
