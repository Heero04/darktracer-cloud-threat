# ===========================================================
#                     DarkTracer Cloud Threat
#                     SNS Configuration File
# ===========================================================
# Description: Configures AWS Simple Notification Service (SNS)
#             for threat alerts including topic, subscriptions,
#             encryption, and access policies
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            SNS Topic Configuration
# ----------------------------------------------------------
# Purpose: Creates main SNS topic for threat alerts
# Features:
# - Environment-specific naming
# - Server-side encryption
# - Resource tagging
# - KMS integration
# ----------------------------------------------------------

resource "aws_sns_topic" "threat_alerts" {
  name = "${var.project_name}-threat-alerts-topic-${terraform.workspace}"

  # Enable server-side encryption using AWS managed KMS key
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = "${var.project_name}-threat-alerts"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# ----------------------------------------------------------
#            Email Subscription Configuration
# ----------------------------------------------------------
# Purpose: Sets up email notification for threat alerts
# Features:
# - Email delivery protocol
# - Topic subscription
# - Variable-based endpoint
# - Alert routing
# ----------------------------------------------------------

resource "aws_sns_topic_subscription" "threat_alerts_email" {
  topic_arn = aws_sns_topic.threat_alerts.arn
  protocol  = "email"    # Email delivery protocol
  endpoint  = var.alert_email  # Email address from variables
}

# ----------------------------------------------------------
#            Topic Access Policy
# ----------------------------------------------------------
# Purpose: Defines permissions for SNS topic access
# Features:
# - Lambda publishing permissions
# - Account-level security
# - Conditional access
# - Service principal configuration
# ----------------------------------------------------------

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]  # Allow Lambda to publish
    }

    actions = [
      "sns:Publish"  # Permission to publish messages
    ]

    resources = [
      aws_sns_topic.threat_alerts.arn  # Specific topic access
    ]

    # Ensure messages only come from our account
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}
