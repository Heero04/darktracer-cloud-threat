# Variable to specify the AWS region for resource deployment
# This can be overridden when applying the Terraform configuration
variable "aws_region" {
  description = "AWS region to deploy to"
  default     = "us-east-1"
}

# Name of the EC2 key pair to be used for SSH access to EC2 instances
variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

# Map of common tags that will be applied to all resources created by this Terraform configuration
# Includes project name, environment and management tool information
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "darktracer"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# Project name that will be used as a prefix for naming AWS resources
# This helps identify resources belonging to this project
variable "project_name" {
  description = "Prefix for naming resources"
  type        = string
  default     = "darktracer"
}

resource "aws_key_pair" "kali_key" {
  key_name   = "kali-key"
  public_key = file("kali-key.pub")
}

variable "alert_email" {
  description = "Email address to receive threat alerts"
  type        = string
}

variable "model_bucket" {
  description = "S3 bucket where the ONNX model is stored"
  type        = string
}

variable "model_key" {
  description = "S3 key (path) to the ONNX model file"
  type        = string
}
