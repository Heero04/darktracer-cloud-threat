# IAM Role for Flow Logs to write to CloudWatch Logs or S3
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "${var.project_name}-vpcflow-role-${terraform.workspace}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# VPC Flow Logs (logs to CloudWatch Logs group)
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs/${var.project_name}-${terraform.workspace}"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-flowlogs-${terraform.workspace}"
  })
}

# VPC Flow Log configuration to capture all network traffic in the VPC
# Logs are sent to CloudWatch Logs group and requires IAM role for permissions
resource "aws_flow_log" "honeypot_vpc_flow" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-flow-${terraform.workspace}"
  })
}
