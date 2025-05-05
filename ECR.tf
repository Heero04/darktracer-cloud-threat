
# ----------------------------------------
#             Sagemaker
# ----------------------------------------
resource "aws_ecr_repository" "sagemaker_trainer" {
  name = "darktracer-sagemaker-trainer"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "SageMaker Training Image"
    Environment = terraform.workspace
    Project     = var.project_name
  }
}
