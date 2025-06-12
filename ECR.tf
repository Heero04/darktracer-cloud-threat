# ===========================================================
#                     DarkTracer Cloud Threat
#                     ECR Configuration File
# ===========================================================
# Description: Configures Amazon Elastic Container Registry (ECR)
#             repositories for storing Docker images used in
#             DarkTracer's SageMaker training and inference
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#                SageMaker Trainer Repository
# ----------------------------------------------------------
# Purpose: Creates and configures ECR repository for SageMaker 
#          training images
# Features:
# - Image vulnerability scanning
# - AES-256 encryption
# - Environment-specific tagging
# ----------------------------------------------------------

resource "aws_ecr_repository" "sagemaker_trainer" {
  name = "darktracer-sagemaker-trainer"

  # Automatically delete the repository even if images exist
  force_delete = true
  
  # Enable automatic vulnerability scanning for container images
  image_scanning_configuration {
    scan_on_push = true
  }

  # Configure server-side encryption for the repository
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Apply standard tags for resource management
  tags = {
    Name        = "SageMaker Training Image"
    Environment = terraform.workspace
    Project     = var.project_name
  }
}
