# ===========================================================
#                     DarkTracer Cloud Threat
#                     SSM Configuration File
# ===========================================================
# Description: Configures AWS Systems Manager Parameter Store
#             for CloudWatch Agent configuration and sets up
#             agent deployment to EC2 instances
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            CloudWatch Agent Parameter Configuration
# ----------------------------------------------------------
# Purpose: Stores CloudWatch Agent configuration in SSM
# Features:
# - JSON configuration storage
# - Parameter overwrite capability
# - Standard tagging
# - Configuration versioning
# ----------------------------------------------------------

resource "aws_ssm_parameter" "cloudwatch_config" {
  name      = "CWA_config"                 # Parameter name in SSM
  type      = "String"                     # Parameter type
  
  # Load configuration from JSON file
  value     = file("${path.module}/config/cloudwatch-agent-config.json")
  
  # Allow configuration updates
  overwrite = true                         
  
  # Apply standard and specific tags
  tags = merge(var.common_tags, {
    Name = "cloudwatch-agent-config"
  })
}

# ----------------------------------------------------------
#            CloudWatch Agent Association Configuration
# ----------------------------------------------------------
# Purpose: Deploys and configures CloudWatch Agent on EC2
# Features:
# - Target instance specification
# - Agent configuration parameters
# - Automatic restart capability
# - Dependency management
# ----------------------------------------------------------

resource "aws_ssm_association" "cloudwatch_agent_config" {
  # Use AWS-provided document for CloudWatch Agent management
  name = "AmazonCloudWatch-ManageAgent"

  # Specify target EC2 instances
  targets {
    key    = "InstanceIds"
    values = [aws_instance.honeypot.id]    # Target specific instance
  }

  # Agent configuration parameters
  parameters = {
    # Specify the action to take
    action                        = "configure"
    
    # Set EC2 mode for the agent
    mode                          = "ec2"
    
    # Use SSM Parameter Store for configuration
    optionalConfigurationSource   = "ssm"
    
    # Specify the configuration parameter name
    optionalConfigurationLocation = "CWA_config"
    
    # Restart agent after configuration
    optionalRestart               = "yes"
  }

  # Ensure required resources exist before creating association
  depends_on = [
    aws_ssm_parameter.cloudwatch_config,   # Wait for parameter creation
    time_sleep.wait_for_ec2                # Wait for EC2 instance
  ]
}
