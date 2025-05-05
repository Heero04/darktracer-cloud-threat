# ===========================================================
#                     DarkTracer Cloud Threat
#                     Main Configuration File
# ===========================================================
# Description: Main Terraform configuration file that sets up
#             provider requirements, default tags, and baseline
#             security analysis for the DarkTracer platform
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            Terraform Provider Configuration
# ----------------------------------------------------------
# Purpose: Defines required providers and versions
# Features:
# - AWS provider specification
# - Version constraints
# - Provider source definition
# ----------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"  # Using latest 5.x AWS provider
    }
  }
}

# ----------------------------------------------------------
#            AWS Provider Configuration
# ----------------------------------------------------------
# Purpose: Configures AWS provider settings and default tags
# Features:
# - Region specification
# - Default resource tagging
# - Environment tracking
# - Cost allocation
# ----------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "darktracer-cloud-threat"  # Project identifier
      Environment = terraform.workspace        # Dynamic environment tracking
      Owner       = "team-engineering"        # Team ownership
      CostCenter  = "cloud-security"          # Cost tracking
      Service     = "threat-monitoring"       # Service classification
    }
  }
}

# ----------------------------------------------------------
#            IAM Access Analyzer Configuration
# ----------------------------------------------------------
# Purpose: Enables security analysis for IAM resources
# Features:
# - Account-level analysis
# - External access monitoring
# - Security visibility
# - Resource tagging
# ----------------------------------------------------------

resource "aws_accessanalyzer_analyzer" "default" {
  analyzer_name = "default-access-analyzer"
  type          = "ACCOUNT"                # Account-level analysis
  
  tags = {
    Purpose = "Baseline IAM visibility"    # Resource purpose tracking
  }
}
