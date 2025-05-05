# ===========================================================
#                     DarkTracer Cloud Threat
#                     WAF Configuration File
# ===========================================================
# Description: Configures AWS WAF (Web Application Firewall)
#             including ACL rules, IP sets, and logging for
#             the DarkTracer threat protection system
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            WAF Web ACL Configuration
# ----------------------------------------------------------
# Purpose: Creates main WAF ACL with protection rules
# Features:
# - Regional scope
# - Default allow action
# - Multiple protection rules
# - Metrics enabled
# ----------------------------------------------------------

resource "aws_wafv2_web_acl" "threat_acl" {
  name        = "${var.project_name}-web-acl-${terraform.workspace}"
  description = "WAF ACL for honeypot threat protection"
  scope       = "REGIONAL"                # Regional WAF deployment

  # Default action for requests that don't match any rules
  default_action {
    allow {}
  }

  # ----------------------------------------------------------
  # Rule 1: Honeypot IP Blocking
  # Purpose: Blocks IPs identified by honeypot system
  # Priority: 1 (Highest)
  # ----------------------------------------------------------
  rule {
    name     = "BlockBadIPs"
    priority = 1

    action {
      block {}                           # Block matching requests
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

  # ----------------------------------------------------------
  # Rule 2: AWS Managed Rules
  # Purpose: Common protection against web vulnerabilities
  # Priority: 2
  # ----------------------------------------------------------
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}                           # Use default rule actions
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        version     = null              # Use latest version
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Global visibility configuration
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAFWebACL"
    sampled_requests_enabled   = true
  }

  # Resource tags
  tags = {
    Name        = "${var.project_name}-waf-acl"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# ----------------------------------------------------------
#            IP Set Configuration
# ----------------------------------------------------------
# Purpose: Manages blocked IP addresses
# Features:
# - IPv4 support
# - Dynamic updates
# - Regional scope
# - Empty initial state
# ----------------------------------------------------------

resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "${var.project_name}-blocked-ip-set-${terraform.workspace}"
  description        = "IP set for blocking threats detected by honeypot"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = []               # Initially empty IP set

  tags = {
    Name        = "${var.project_name}-blocked-ips"
    Environment = terraform.workspace
    Project     = var.project_name
    Terraform   = "true"
  }
}

# ----------------------------------------------------------
#            WAF Logging Configuration
# ----------------------------------------------------------
# Purpose: Configures CloudWatch logging for WAF
# Features:
# - 30-day retention
# - Structured log path
# - Standard tagging
# ----------------------------------------------------------

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

# ----------------------------------------------------------
#            Output Values
# ----------------------------------------------------------
# Purpose: Exports WAF configuration values
# Usage: Referenced by other resources/modules
# ----------------------------------------------------------

output "waf_ip_set_id" {
  value       = aws_wafv2_ip_set.blocked_ips.id
  description = "The ID of the WAF IP set for blocking threats"
}
