resource "aws_s3_bucket" "training_bucket" {
  bucket = "${var.project_name}-training-bucket-${terraform.workspace}"

  tags = {
    Name        = "${var.project_name}-training-bucket-${terraform.workspace}"
    Environment = terraform.workspace
    Project     = var.project_name
  }

  force_destroy = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.training_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.training_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_policy" "sagemaker_bucket_access" {
  name        = "${var.project_name}-sagemaker-s3-access-${terraform.workspace}"
  description = "Allow SageMaker to access training and logs buckets"

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


