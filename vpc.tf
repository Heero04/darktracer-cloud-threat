# ===========================================================
#                     DarkTracer Cloud Threat
#                     VPC Configuration File
# ===========================================================
# Description: Configures Virtual Private Cloud (VPC) network
#             infrastructure including subnets, routing, and
#             security groups for the DarkTracer platform
# 
# Last Updated: 2024-04-19
# ===========================================================

# ----------------------------------------------------------
#            VPC Configuration
# ----------------------------------------------------------
# Purpose: Creates main VPC with DNS capabilities
# Features:
# - Large CIDR range for multiple subnets
# - DNS support for resource naming
# - Hostname assignment enabled
# - Environment-specific tagging
# ----------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"     # 65,536 available IP addresses
  enable_dns_support   = true              # Enable DNS resolution
  enable_dns_hostnames = true              # Enable DNS hostnames

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Internet Gateway Configuration
# ----------------------------------------------------------
# Purpose: Provides internet connectivity for the VPC
# Features:
# - VPC attachment
# - Public internet access
# - Standard tagging
# ----------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                # Attach to main VPC

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Public Subnet Configuration
# ----------------------------------------------------------
# Purpose: Creates public subnet for internet-facing resources
# Features:
# - Specific availability zone placement
# - Auto-assign public IPs
# - CIDR block allocation
# - Standard tagging
# ----------------------------------------------------------

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"   # 256 IP addresses
  map_public_ip_on_launch = true            # Auto-assign public IPs
  availability_zone       = "${var.aws_region}a"  # Specific AZ

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-subnet-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Route Table Configuration
# ----------------------------------------------------------
# Purpose: Manages routing for public subnet
# Features:
# - VPC association
# - Standard tagging
# - Traffic management
# ----------------------------------------------------------

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt-${terraform.workspace}"
  })
}

# ----------------------------------------------------------
#            Internet Route Configuration
# ----------------------------------------------------------
# Purpose: Enables internet access via IGW
# Features:
# - Default route to internet
# - IGW association
# - All-destination routing
# ----------------------------------------------------------

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"      # All traffic
  gateway_id             = aws_internet_gateway.igw.id
}

# ----------------------------------------------------------
#            Route Table Association
# ----------------------------------------------------------
# Purpose: Links public subnet to route table
# Features:
# - Subnet association
# - Route table linking
# - Traffic flow enablement
# ----------------------------------------------------------

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# ----------------------------------------------------------
#            SageMaker Security Group
# ----------------------------------------------------------
# Purpose: Controls network access for SageMaker endpoints
# Features:
# - Outbound internet access
# - Security rules
# - VPC association
# ----------------------------------------------------------

resource "aws_security_group" "sagemaker_sg" {
  name        = "sagemaker-sg"
  description = "Security group for SageMaker model"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0                       # All ports
    to_port     = 0                       # All ports
    protocol    = "-1"                    # All protocols
    cidr_blocks = ["0.0.0.0/0"]          # All destinations
  }
}
