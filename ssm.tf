# AWS SSM Parameter to store CloudWatch Agent configuration
# This parameter is used to configure the CloudWatch agent on EC2 instances
# The configuration is loaded from a JSON file and can be overwritten if needed
resource "aws_ssm_parameter" "cloudwatch_config" {
  name      = "CWA_config"
  type      = "String"
  value     = file("${path.module}/config/cloudwatch-agent-config.json")
  overwrite = true
  tags = merge(var.common_tags, {
    Name = "cloudwatch-agent-config"
  })
}

resource "aws_ssm_association" "cloudwatch_agent_config" {
  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.honeypot.id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = "CWA_config"
    optionalRestart               = "yes"
  }

  depends_on = [aws_ssm_parameter.cloudwatch_config, time_sleep.wait_for_ec2]
}

