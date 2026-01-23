# =============================================================================
# VPC CONFIGURATION - Network Infrastructure
# =============================================================================
# Creates a VPC with:
# - 2 Public Subnets (MongoDB VM, Load Balancer)
# - 2 Private Subnets (EKS worker nodes)
# - Internet Gateway (public internet access)
# - NAT Gateway (private subnet outbound access)
# - Route tables for traffic routing
#
# WHY PUBLIC VS PRIVATE SUBNETS MATTER:
# - Public Subnet: Has route to Internet Gateway, instances get public IPs
# - Private Subnet: No direct internet route, must go through NAT Gateway
# - MongoDB VM in public subnet = INTENTIONAL WEAKNESS (SSH exposed)
# - EKS in private subnet = CORRECT PRACTICE (not directly accessible)
# =============================================================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway - Allows public subnets to reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway - Allows private subnets to reach internet (outbound only)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # NAT GW lives in public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Subnets (2 for high availability)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true  # Instances get public IPs automatically

  tags = {
    Name                                           = "${var.project_name}-public-${count.index + 1}"
    "kubernetes.io/role/elb"                       = "1"  # For ALB ingress controller
    "kubernetes.io/cluster/${var.project_name}"   = "shared"
  }
}

# Private Subnets (2 for high availability - EKS nodes go here)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false  # No public IPs - more secure

  tags = {
    Name                                           = "${var.project_name}-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb"              = "1"  # For internal load balancers
    "kubernetes.io/cluster/${var.project_name}"   = "shared"
  }
}

# Public Route Table - Routes to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"  # All traffic not destined for VPC
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Private Route Table - Routes to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
