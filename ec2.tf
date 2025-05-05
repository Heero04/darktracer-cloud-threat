# Security group for the honeypot instance
# Allows inbound SSH (22) and HTTP (80) traffic from anywhere
# Allows all outbound traffic
resource "aws_security_group" "honeypot_sg" {
  name        = "${var.project_name}-honeypot-sg-${terraform.workspace}"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "FTP"
    from_port   = 21
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-honeypot-sg-${terraform.workspace}"
  })
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name      = "/CWA_config"
  type      = "String"
  value     = templatefile("${path.root}/modules/cloudwatch/cwagent-config.tpl.json", {})
  overwrite = true # Add this line to allow overwriting existing parameter
}



# EC2 instance that serves as the honeypot
# Uses Amazon Linux 2 AMI and t2.micro instance type
# Placed in public subnet with public IP for accessibility
resource "aws_instance" "honeypot" {
  ami                         = "ami-0c02fb55956c7d316" # Replace with Ubuntu AMI if needed
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.honeypot_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on                  = [aws_ssm_parameter.cloudwatch_agent_config]

  user_data = <<-EOF
  #!/bin/bash
  set -e  # Exit on error
  set -x  # Enable command tracing

  # Update system
  yum update -y

  # Install CloudWatch Agent
  cd /tmp
  curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
  rpm -U ./amazon-cloudwatch-agent.rpm

  # Make sure the agent is started
  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent

  # Initial configuration
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c ssm:/CWA_config \
    -s
EOF


  tags = merge(var.common_tags, {
    Name = "${var.project_name}-honeypot-${terraform.workspace}"
  })
}

# Wait for the EC2 instance to be in a running state before proceeding
# This is useful if you have any dependencies that need to wait for the instance to be fully up
resource "time_sleep" "wait_for_ec2" {
  depends_on      = [aws_instance.honeypot]
  create_duration = "60s"
}

resource "null_resource" "refresh_cloudwatch_agent" {
  triggers = {
    config_hash = sha256(jsonencode(aws_ssm_parameter.cloudwatch_agent_config.value))
  }

  provisioner "remote-exec" {
    inline = [
      "set -x",                                                                          # Enable command tracing
      "sudo systemctl status amazon-cloudwatch-agent",                                   # Check if agent is running
      "ls -l /opt/aws/amazon-cloudwatch-agent/bin/",                                     # Verify binary exists
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status", # Check agent status
      "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c ssm:/CWA_config -s"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("darktracer-keypair.pem")
      host        = aws_instance.honeypot.public_ip
      timeout     = "2m"
    }
  }

}
