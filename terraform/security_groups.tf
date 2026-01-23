# =============================================================================
# SECURITY GROUPS - Virtual Firewalls
# =============================================================================
# Security groups are STATEFUL firewalls:
# - If inbound traffic is allowed, the response is automatically allowed
# - Rules are evaluated as a group (if ANY rule allows, traffic is permitted)
#
# KEY WEAKNESSES:
# - wiz-mongo-sg allows SSH from 0.0.0.0/0 (ANYWHERE on internet)
# - 0.0.0.0/0 means "all IP addresses" - any attacker can attempt connection
# =============================================================================

# MongoDB VM Security Group
resource "aws_security_group" "mongodb" {
  name        = "${var.project_name}-mongo-sg"
  description = "Security group for MongoDB VM - INTENTIONALLY WEAK SSH RULE"
  vpc_id      = aws_vpc.main.id

  # INTENTIONAL WEAKNESS: SSH from anywhere
  # In production, this should be restricted to specific IPs or VPN only
  ingress {
    description = "SSH from anywhere - INTENTIONAL WEAKNESS"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ANY IP can attempt SSH - DANGEROUS!
  }

  # MongoDB port - CORRECT: Only from within VPC
  ingress {
    description = "MongoDB from VPC only - CORRECT"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]  # Only 10.0.0.0/16 can connect
  }

  # Allow all outbound traffic (standard practice)
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-mongo-sg"
    Warning = "SSH-EXPOSED-TO-INTERNET"
  }
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  # Allow all traffic from within the security group (node-to-node)
  ingress {
    description = "Allow all internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-cluster-sg"
  }
}

# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Allow all traffic from cluster security group
  ingress {
    description     = "Allow from EKS cluster"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # Allow node-to-node communication
  ingress {
    description = "Allow node-to-node"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Allow kubelet API from cluster
  ingress {
    description     = "Kubelet API"
    from_port       = 10250
    to_port         = 10250
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-nodes-sg"
  }
}

# Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere (expected for web app)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS from anywhere (expected for web app)
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Allow EKS nodes to receive traffic from ALB
resource "aws_security_group_rule" "nodes_from_alb" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.eks_nodes.id
  description              = "Allow NodePort traffic from ALB"
}
