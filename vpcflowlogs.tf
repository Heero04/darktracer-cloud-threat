# ===========================================================
#                     DarkTracer Cloud Threat
#                     VPC Flow Logs Configuration
# ===========================================================
# Description: Configures VPC Flow Logs to capture and monitor
#             network traffic, including IAM roles, CloudWatch
#             log groups, and flow log settings
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            Flow Logs IAM Role
# ----------------------------------------------------------
# Purpose: Creates IAM role for VPC Flow Logs service
# Features:
# - Trust relationship with Flow Logs service
# - Environment-specific naming
# - Required permissions for log delivery
# - Secure role configuration
# ----------------------------------------------------------

resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.project_name}-vpcflow-role-${terraform.workspace}"

  # Define trust relationship for VPC Flow Logs service
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"  # VPC Flow Logs service principal
        },
        Action = "sts:AssumeRole"                 # Allow service to assume role
      }
    ]
  })
}

# ----------------------------------------------------------
#            CloudWatch Log Group Configuration
# ----------------------------------------------------------
# Purpose: Creates log group for storing VPC flow logs
# Features:
# - Structured log path
# - Log retention policy
# - Resource tagging
# - Environment separation
# ----------------------------------------------------------

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${terraform.workspace}"
  retention_in_days = 7                    # 7-day retention period

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-flowlogs-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            VPC Flow Log Configuration
# ----------------------------------------------------------
# Purpose: Enables flow log capture for VPC traffic
# Features:
# - All traffic capture
# - CloudWatch integration
# - IAM role association
# - VPC traffic monitoring
# - Resource tagging
# ----------------------------------------------------------

resource "aws_flow_log" "honeypot_vpc_flow" {
  # CloudWatch Logs configuration
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  
  # Traffic capture settings
  traffic_type         = "ALL"             # Capture all traffic types
  vpc_id               = aws_vpc.main.id   # Target VPC
  
  # IAM role for log delivery
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  # Resource identification
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-flow-${terraform.workspace}"
  })
}
