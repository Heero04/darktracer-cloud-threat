#----------------------------------------------------------
# WAF (Web Application Firewall) Configuration
#----------------------------------------------------------

resource "aws_wafv2_web_acl" "threat_acl" {
  name        = "${var.project_name}-web-acl-${terraform.workspace}"
  description = "WAF ACL for honeypot threat protection"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Block IPs from honeypot detection
  rule {
    name     = "BlockBadIPs"
    priority = 1

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockedHoneypotIPs"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        version     = null # Use null for latest version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAFWebACL"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.project_name}-waf-acl"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# IP Set Configuration
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "${var.project_name}-blocked-ip-set-${terraform.workspace}"
  description        = "IP set for blocking threats detected by honeypot"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = [] # Initially empty

  tags = {
    Name        = "${var.project_name}-blocked-ips"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# CloudWatch Log Group for WAF Logs
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/waf/${var.project_name}-${terraform.workspace}"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-waf-logs"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# Output the WAF IP Set ID for Lambda environment variable
output "waf_ip_set_id" {
  value       = aws_wafv2_ip_set.blocked_ips.id
  description = "The ID of the WAF IP set for blocking threats"
}
