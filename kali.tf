resource "aws_instance" "kali" {
  ami                    = "ami-0206d67558efa3db1" # The AMI you just found
  instance_type          = "t3.micro"              # Safer, smarter choice
  key_name               = aws_key_pair.kali_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.kali_sg.id]

  tags = {
    Name = "Kali-T3"
  }
}

# First, create the security group
resource "aws_security_group" "kali_sg" {
  name        = "kali_security_group"
  description = "Security group for Kali instance"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["98.46.114.122/32"] # Replace with your IP
  }

  # Allow all outbound traffic
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

