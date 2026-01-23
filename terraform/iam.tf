# =============================================================================
# IAM CONFIGURATION - Identity and Access Management
# =============================================================================
# IAM roles define WHAT a resource can do in AWS
#
# KEY WEAKNESS:
# - MongoDB VM has ec2:* and s3:* permissions - WAY too broad
# - Violates "least privilege" principle
# - If VM is compromised, attacker gets full EC2 and S3 access
#
# CORRECT PRACTICE:
# - Only grant specific permissions needed (e.g., s3:PutObject on one bucket)
# =============================================================================

# ----- MONGODB VM IAM ROLE (INTENTIONALLY OVERPERMISSIVE) -----

# IAM role that can be assumed by EC2 instances
resource "aws_iam_role" "mongodb" {
  name = "${var.project_name}-mongodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.project_name}-mongodb-role"
    Warning = "INTENTIONALLY-OVERPERMISSIVE"
  }
}

# INTENTIONAL WEAKNESS: Overly permissive policy
resource "aws_iam_role_policy" "mongodb_overpermissive" {
  name = "${var.project_name}-mongodb-overpermissive-policy"
  role = aws_iam_role.mongodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # INTENTIONAL WEAKNESS: Full EC2 access
        # An attacker could: create new instances, terminate instances,
        # modify security groups, etc.
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        # INTENTIONAL WEAKNESS: Full S3 access
        # An attacker could: read ALL buckets, download ALL data,
        # delete backups, exfiltrate sensitive data
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      }
    ]
  })
}

# Instance profile - allows EC2 to use the role
resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb.name
}

# ----- EKS CLUSTER IAM ROLE -----

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ----- EKS NODE GROUP IAM ROLE -----

resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-eks-nodes-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ----- OIDC Provider for EKS Service Accounts -----

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
