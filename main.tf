# Configure Terraform and required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94.1"
    }
  }
}

# Configure the AWS Provider with default tags
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "darktracer-cloud-threat"
      Environment = terraform.workspace
      Owner       = "team-engineering"
      CostCenter  = "cloud-security"
      Service     = "threat-monitoring"
    }
  }
}

# Enable IAM Access Analyzer to monitor external access to resources
resource "aws_accessanalyzer_analyzer" "default" {
  analyzer_name = "default-access-analyzer"
  type          = "ACCOUNT"
  tags = {
    Purpose = "Baseline IAM visibility"
  }
}
