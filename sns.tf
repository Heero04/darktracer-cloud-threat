# Add this to your existing sns.tf file

#----------------------------------------------------------
# SNS Topic Subscription
# - Adds email subscription for threat alerts
#----------------------------------------------------------
resource "aws_sns_topic_subscription" "threat_alerts_email" {
  topic_arn = aws_sns_topic.threat_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email # Add this variable to your variables.tf
}

#----------------------------------------------------------
# SNS Topic Configuration (Updated with encryption)
#----------------------------------------------------------
resource "aws_sns_topic" "threat_alerts" {
  name = "${var.project_name}-threat-alerts-topic-${terraform.workspace}"

  # Optional: Enable server-side encryption
  kms_master_key_id = "alias/aws/sns" # Uses AWS managed KMS key

  tags = {
    Name        = "${var.project_name}-threat-alerts"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

#----------------------------------------------------------
# Updated SNS Topic Policy
#----------------------------------------------------------
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.threat_alerts.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

