# ===========================================================
#                     DarkTracer Cloud Threat
#                     CloudWatch Configuration
# ===========================================================
# Description: Configures CloudWatch resources including event rules,
#             log groups, and event targets for the DarkTracer 
#             threat detection system
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            CloudWatch Event Rule Configuration
# ----------------------------------------------------------
# Purpose: Sets up daily trigger for Athena unload operations
# Includes:
# - Event rule definition
# - Schedule configuration
# - Tag management
# ----------------------------------------------------------

resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_name}-daily-athena-unload-${terraform.workspace}"
  description         = "Triggers Athena unload Lambda function once per day"
  schedule_expression = "cron(0 15 * * ? *)"

  tags = local.common_tags
}

# ----------------------------------------------------------
#            CloudWatch Event Target Configuration
# ----------------------------------------------------------
# Purpose: Links CloudWatch Events to Lambda function
# Includes:
# - Event target specification
# - Lambda function association
# ----------------------------------------------------------

resource "aws_cloudwatch_event_target" "athena_unload_target" {
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "AthenaDailyUnload"
  arn       = aws_lambda_function.athena_unload.arn
}

# ----------------------------------------------------------
#            Lambda Permissions Configuration
# ----------------------------------------------------------
# Purpose: Sets up necessary permissions for CloudWatch
# Includes:
# - CloudWatch Events invoke permissions
# - Lambda function access rights
# ----------------------------------------------------------

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchEventsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_unload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# ----------------------------------------------------------
#            CloudWatch Log Groups Configuration
# ----------------------------------------------------------
# Purpose: Defines log groups for Lambda functions
# Includes:
# - Log retention settings
# - Tag management
# ----------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.athena_unload.function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_threat_analyzer" {
  name              = "/aws/lambda/lambda_threat_analyzer"
  retention_in_days = 14

  tags = local.common_tags
}

# ----------------------------------------------------------
#            Common Tags Configuration
# ----------------------------------------------------------
# Purpose: Defines standard tags for all resources
# Includes:
# - Project identification
# - Environment specification
# - Service categorization
# ----------------------------------------------------------

locals {
  common_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
    Terraform   = "true"
    Service     = "threat-monitoring"
  }
}

# ----------------------------------------------------------
#            OpenCanary Log Subscription Configuration
# ----------------------------------------------------------
# Purpose: Sets up log subscription for honeypot monitoring
# Includes:
# - Log subscription filter
# - Lambda function permissions
# ----------------------------------------------------------

resource "aws_cloudwatch_log_subscription_filter" "honeypot_logs" {
  name            = "honeypot-logs-filter"
  log_group_name  = "/darktracer/honeypot/opencanary"
  filter_pattern  = "" # Empty pattern to capture all logs
  destination_arn = aws_lambda_function.lambda_threat_analyzer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_honeypot" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_threat_analyzer.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn    = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/darktracer/honeypot/opencanary:*"
}
