# CloudWatch Event Rule
resource "aws_cloudwatch_event_rule" "daily_trigger" {
  name                = "${var.project_name}-daily-athena-unload-${terraform.workspace}"
  description         = "Triggers Athena unload Lambda function once per day"
  schedule_expression = "cron(0 15 * * ? *)"

  tags = local.common_tags
}

# CloudWatch Event Target for Athena unload
resource "aws_cloudwatch_event_target" "athena_unload_target" { # Changed from "lambda_target"
  rule      = aws_cloudwatch_event_rule.daily_trigger.name
  target_id = "AthenaDailyUnload"
  arn       = aws_lambda_function.athena_unload.arn
}


# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchEventsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_unload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_trigger.arn
}

# CloudWatch Log Group
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


# Common tags
locals {
  common_tags = {
    Project     = var.project_name
    Environment = terraform.workspace
    Terraform   = "true"
    Service     = "threat-monitoring"
  }
}

# Add the new OpenCanary log subscription configuration here
# CloudWatch Log Subscription Filter for OpenCanary Logs
resource "aws_cloudwatch_log_subscription_filter" "honeypot_logs" {
  name            = "honeypot-logs-filter"
  log_group_name  = "/darktracer/honeypot/opencanary"
  filter_pattern  = "" # Empty pattern to capture all logs
  destination_arn = aws_lambda_function.lambda_threat_analyzer.arn
}

# Lambda Permission for CloudWatch Logs
resource "aws_lambda_permission" "allow_cloudwatch_honeypot" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_threat_analyzer.function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn    = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/darktracer/honeypot/opencanary:*"
}