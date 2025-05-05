# ===========================================================
#                     DarkTracer Cloud Threat
#                     Variables Configuration
# ===========================================================
# Description: Defines all variables used across the DarkTracer
#             infrastructure, including AWS region, resource
#             naming, tags, and configuration parameters
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            AWS Region Configuration
# ----------------------------------------------------------
# Purpose: Specifies the AWS region for resource deployment
# Default: US East (N. Virginia)
# Usage: Can be overridden via terraform.tfvars or CLI
# ----------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

# ----------------------------------------------------------
#            EC2 Key Pair Configuration
# ----------------------------------------------------------
# Purpose: Defines SSH key pair for EC2 instance access
# Type: Required input (no default)
# Usage: Must be provided during terraform apply
# ----------------------------------------------------------

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

# ----------------------------------------------------------
#            Common Resource Tags
# ----------------------------------------------------------
# Purpose: Defines standard tags applied to all resources
# Features:
# - Project identification
# - Environment tracking
# - Management tool identification
# ----------------------------------------------------------

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "darktracer"    # Project identifier
    Environment = "dev"           # Default environment
    ManagedBy   = "terraform"     # Infrastructure management tool
  }
}

# ----------------------------------------------------------
#            Project Name Configuration
# ----------------------------------------------------------
# Purpose: Defines prefix for resource naming
# Usage: Applied to resource names for identification
# Default: "darktracer"
# ----------------------------------------------------------

variable "project_name" {
  description = "Prefix for naming resources"
  type        = string
  default     = "darktracer"
}

# ----------------------------------------------------------
#            SSH Key Pair Resource
# ----------------------------------------------------------
# Purpose: Creates SSH key pair for EC2 access
# Features:
# - Public key import
# - Key name specification
# - File-based configuration
# ----------------------------------------------------------

resource "aws_key_pair" "kali_key" {
  key_name   = "kali-key"
  public_key = file("kali-key.pub")    # Loads public key from file
}

# ----------------------------------------------------------
#            Alert Configuration
# ----------------------------------------------------------
# Purpose: Defines email address for threat notifications
# Type: Required input (no default)
# Usage: Must be provided during terraform apply
# ----------------------------------------------------------

variable "alert_email" {
  description = "Email address to receive threat alerts"
  type        = string
}

# ----------------------------------------------------------
#            Model Configuration
# ----------------------------------------------------------
# Purpose: Defines S3 location for ONNX model storage
# Type: Required inputs (no defaults)
# Usage: Must be provided during terraform apply
# ----------------------------------------------------------

variable "model_bucket" {
  description = "S3 bucket where the ONNX model is stored"
  type        = string
}

variable "model_key" {
  description = "S3 key (path) to the ONNX model file"
  type        = string
}
