# ===========================================================
#                     DarkTracer Cloud Threat
#                     Glue Configuration File
# ===========================================================
# Description: Configures AWS Glue resources including database,
#             crawler, and ETL jobs for log processing and 
#             threat analysis
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#                     S3 Bucket Configuration
# ----------------------------------------------------------
# Purpose: Creates and configures S3 bucket for cleaned logs
# Features:
# - Environment-specific naming
# - Force destroy enabled for cleanup
# - Standard tagging strategy
# ----------------------------------------------------------

resource "aws_s3_bucket" "cleaned_logs" {
  bucket        = "${var.project_name}-cleaned-logs-${terraform.workspace}"
  force_destroy = true

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ----------------------------------------------------------
#                  Glue Database Configuration
# ----------------------------------------------------------
# Purpose: Creates Glue catalog database for storing metadata
# Features:
# - Environment-specific naming
# - Metadata management
# - Resource tagging
# ----------------------------------------------------------

resource "aws_glue_catalog_database" "clean_logs_db" {
  name = "${var.project_name}_clean_logs_${terraform.workspace}"

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ----------------------------------------------------------
#                  Glue Crawler Configuration
# ----------------------------------------------------------
# Purpose: Sets up Glue crawler for automated schema discovery
# Features:
# - Daily schedule (noon UTC)
# - S3 target configuration
# - Partition handling
# - IAM role integration
# ----------------------------------------------------------

resource "aws_glue_crawler" "clean_logs_crawler" {
  name          = "${var.project_name}-crawler-${terraform.workspace}"
  role          = aws_iam_role.glue_service_role.arn
  database_name = aws_glue_catalog_database.clean_logs_db.name

  s3_target {
    path = "s3://${aws_s3_bucket.cleaned_logs.bucket}/"
  }

  schedule = "cron(0 12 * * ? *)"

  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
  })

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ----------------------------------------------------------
#                  IAM Role Configuration
# ----------------------------------------------------------
# Purpose: Defines IAM role for Glue service
# Features:
# - Service principal configuration
# - AssumeRole policy
# - Resource tagging
# ----------------------------------------------------------

resource "aws_iam_role" "glue_service_role" {
  name = "${var.project_name}-glue-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ----------------------------------------------------------
#                  IAM Policy Configuration
# ----------------------------------------------------------
# Purpose: Defines permissions for Glue service role
# Features:
# - S3 bucket access permissions
# - Glue service permissions
# - CloudWatch logging permissions
# - Resource-specific access control
# ----------------------------------------------------------

resource "aws_iam_role_policy" "glue_policy" {
  name = "${var.project_name}-glue-policy-${terraform.workspace}"
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          # Source bucket
          "arn:aws:s3:::darktracer-logs-dev",
          "arn:aws:s3:::darktracer-logs-dev/*",
          # Cleaned logs bucket
          "arn:aws:s3:::${var.project_name}-cleaned-logs-${terraform.workspace}",
          "arn:aws:s3:::${var.project_name}-cleaned-logs-${terraform.workspace}/*",
          # Log archive bucket
          "arn:aws:s3:::${var.project_name}-log-archive-${terraform.workspace}",
          "arn:aws:s3:::${var.project_name}-log-archive-${terraform.workspace}/*",
          # Training bucket
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}/*",
          "arn:aws:s3:::${var.project_name}-training-bucket-${terraform.workspace}",
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "glue:*",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketAcl"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:/aws-glue/*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      }
    ]
  })
}

# ----------------------------------------------------------
#                  Glue Job Configuration
# ----------------------------------------------------------
# Purpose: Defines ETL job for log processing
# Features:
# - Python script location
# - Worker configuration
# - Job bookmarks
# - CloudWatch integration
# - Spark configuration
# ----------------------------------------------------------

resource "aws_glue_job" "clean_logs_job" {
  name              = "${var.project_name}-clean-logs-${terraform.workspace}"
  role_arn          = aws_iam_role.glue_service_role.arn
  glue_version      = "4.0"
  number_of_workers = 2
  worker_type       = "G.1X"
  timeout           = 2880 # 48 hours max
  max_retries       = 1

  execution_property {
    max_concurrent_runs = 1
  }

  command {
    name            = "glueetl"
    script_location = "s3://${var.project_name}-cleaned-logs-${terraform.workspace}/scripts/clean_vpc_logs.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--TempDir"                          = "s3://${var.project_name}-cleaned-logs-${terraform.workspace}/tmp/"
    "--project_name"                     = var.project_name
    "--environment"                      = terraform.workspace
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${var.project_name}-cleaned-logs-${terraform.workspace}/spark-logs/"
  }

  notification_property {
    notify_delay_after = 10 # minutes
  }

  tags = {
    Environment = terraform.workspace
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ----------------------------------------------------------
#            CloudWatch Alarm Configuration
# ----------------------------------------------------------
# Purpose: Monitors Glue job failures
# Features:
# - Failure detection
# - Metric monitoring
# - Optional SNS integration
# ----------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "glue_job_failure" {
  alarm_name          = "${var.project_name}-glue-job-failure-${terraform.workspace}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "glue.driver.aggregate.numFailedTasks"
  namespace           = "AWS/Glue"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Glue job failures"
  alarm_actions       = [] # Add SNS topic ARN if needed

  dimensions = {
    JobName = aws_glue_job.clean_logs_job.name
  }
}
