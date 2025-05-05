# ===========================================================
#                     S3 Bucket Configuration
#                     Log Archive and Access Logs
# ===========================================================
# Description: Defines S3 buckets and their configurations for
#             storing Firehose logs and access logging
# Last Updated: YYYY-MM-DD
# ===========================================================

# ----------------------------------------------------------
#            Main Log Archive Bucket Configuration
# ----------------------------------------------------------
# Purpose: Main storage for Firehose logs including:
# - VPC Flow Logs
# - CloudWatch Logs
# - Other system logs
# ----------------------------------------------------------

resource "aws_s3_bucket" "log_archive" {
  bucket        = "${var.project_name}-log-archive-${terraform.workspace}"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-log-archive-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Log Archive Security Configuration
# ----------------------------------------------------------
# Includes:
# - Versioning for log history retention
# - Server-side encryption (AES256)
# - Public access blocking
# - TLS/HTTPS-only access enforcement
# ----------------------------------------------------------

resource "aws_s3_bucket_versioning" "log_archive_versioning" {
  bucket = aws_s3_bucket.log_archive.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive_encryption" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive_block" {
  bucket = aws_s3_bucket.log_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "log_archive_tls_only" {
  bucket = aws_s3_bucket.log_archive.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.log_archive.arn}",
          "${aws_s3_bucket.log_archive.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ----------------------------------------------------------
#            Access Logging Configuration
# ----------------------------------------------------------
# Purpose: Configure access logging for the main archive bucket
# Includes:
# - Access logs bucket creation
# - Access logging configuration
# ----------------------------------------------------------

resource "aws_s3_bucket" "log_archive_access_logs" {
  bucket = "${var.project_name}-log-access-logs-${terraform.workspace}"

  force_destroy = true
}

resource "aws_s3_bucket_logging" "log_archive_logging" {
  bucket = aws_s3_bucket.log_archive.id

  target_bucket = aws_s3_bucket.log_archive_access_logs.id
  target_prefix = "log-archive-access/"
}
