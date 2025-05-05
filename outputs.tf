# Output the public IP address of the honeypot EC2 instance for access
output "honeypot_public_ip" {
  description = "Public IP of the honeypot EC2 instance"
  value       = aws_instance.honeypot.public_ip
}

# Output the public subnet ID for reference and dependencies
output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "sagemaker_trainer_repo_url" {
  value = aws_ecr_repository.sagemaker_trainer.repository_url
}

# Output the public IP address of the Kali Linux EC2 instance for access
output "kali_public_ip" {
  description = "Public IP of the Kali Linux EC2 instance"
  value       = aws_instance.kali.public_ip
}

output "cloudwatch_config_ssm" {
  value = aws_ssm_parameter.cloudwatch_agent_config.name
}
