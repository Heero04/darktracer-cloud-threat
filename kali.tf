# ===========================================================
#                     DarkTracer Cloud Threat
#                     Kali Linux EC2 Configuration
# ===========================================================
# Description: Configures EC2 instance running Kali Linux for
#             security testing and threat analysis within the
#             DarkTracer environment
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#                EC2 Instance Configuration
# ----------------------------------------------------------
# Purpose: Deploys Kali Linux instance for security testing
# Features:
# - AMI specification
# - Instance type selection
# - Network configuration
# - Security group association
# - Tag management
# ----------------------------------------------------------

resource "aws_instance" "kali" {
  ami                    = "ami-0206d67558efa3db1" # Kali Linux AMI
  instance_type          = "t3.micro"              # Cost-effective instance size
  key_name               = aws_key_pair.kali_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.kali_sg.id]

  tags = {
    Name = "Kali-T3"
  }
}

# ----------------------------------------------------------
#            Security Group Configuration
# ----------------------------------------------------------
# Purpose: Defines network access rules for Kali instance
# Features:
# - SSH access control
# - Outbound traffic rules
# - IP-based restrictions
# - Security group tagging
# ----------------------------------------------------------

resource "aws_security_group" "kali_sg" {
  name        = "kali_security_group"
  description = "Security group for Kali instance"
  vpc_id      = aws_vpc.main.id

  # SSH access configuration
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["98.46.114.122/32"] # Restricted to specific IP
  }

  # Outbound traffic configuration
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kali-security-group"
  }
}
