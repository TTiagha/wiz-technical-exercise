# =============================================================================
# EKS CLUSTER - Kubernetes Infrastructure
# =============================================================================
# Creates an EKS cluster with:
# - Control plane (managed by AWS)
# - Worker nodes in PRIVATE subnets (correct security practice)
# - Public endpoint for kubectl access
#
# WHY PRIVATE SUBNETS FOR EKS:
# - Worker nodes don't need public IPs
# - Reduces attack surface - nodes not directly accessible from internet
# - Traffic flows: Internet -> Load Balancer -> Private Node
# - This is CORRECT security practice (contrast with MongoDB VM)
# =============================================================================

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.project_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true  # Allows kubectl from anywhere (for exercise)
  }

  # Enable logging for security monitoring
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id  # PRIVATE subnets (correct practice)

  scaling_config {
    desired_size = var.eks_desired_capacity
    max_size     = 3
    min_size     = 1
  }

  instance_types = [var.eks_node_instance_type]

  # Use latest Amazon Linux 2 EKS AMI
  ami_type = "AL2_x86_64"

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]

  tags = {
    Name = "${var.project_name}-node-group"
  }
}

# ECR Repository for Todo App
resource "aws_ecr_repository" "todo_app" {
  name                 = "${var.project_name}-todo-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true  # Enable vulnerability scanning
  }

  tags = {
    Name = "${var.project_name}-todo-app"
  }
}

# ECR Lifecycle Policy - Keep only 10 most recent images
resource "aws_ecr_lifecycle_policy" "todo_app" {
  repository = aws_ecr_repository.todo_app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}/cluster"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-eks-logs"
  }
}
