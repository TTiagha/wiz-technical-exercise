# =============================================================================
# OUTPUTS - Values to display after terraform apply
# =============================================================================

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# MongoDB VM Outputs
output "mongodb_public_ip" {
  description = "Public IP of MongoDB VM (SSH accessible - INTENTIONAL WEAKNESS)"
  value       = aws_instance.mongodb.public_ip
}

output "mongodb_private_ip" {
  description = "Private IP of MongoDB VM (for K8s connection)"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_connection_string" {
  description = "MongoDB connection string for application"
  value       = "mongodb://todoapp:${var.mongodb_password}@${aws_instance.mongodb.private_ip}:27017/todos?authSource=todos"
  sensitive   = true
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 backup bucket (PUBLIC - INTENTIONAL WEAKNESS)"
  value       = aws_s3_bucket.backups.id
}

output "s3_bucket_url" {
  description = "URL to access the public S3 bucket"
  value       = "https://${aws_s3_bucket.backups.id}.s3.amazonaws.com/"
}

# EKS Outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

# ECR Output
output "ecr_repository_url" {
  description = "URL of ECR repository for todo app"
  value       = aws_ecr_repository.todo_app.repository_url
}

# SSH Key
output "ssh_private_key" {
  description = "Private SSH key for MongoDB VM access"
  value       = tls_private_key.mongodb.private_key_pem
  sensitive   = true
}

output "ssh_key_name" {
  description = "Name of the SSH key pair"
  value       = aws_key_pair.mongodb.key_name
}

# Security Warning
output "security_warnings" {
  description = "List of intentional security weaknesses for the exercise"
  value = <<-EOT

    ⚠️  INTENTIONAL SECURITY WEAKNESSES FOR WIZ EXERCISE:

    1. SSH (port 22) exposed to 0.0.0.0/0 on MongoDB VM
    2. Ubuntu 20.04 LTS (outdated - EOL April 2025)
    3. MongoDB 4.4 (outdated - EOL Feb 2024)
    4. Overly permissive IAM role on MongoDB VM (ec2:*, s3:*)
    5. S3 bucket is PUBLIC with database backups
    6. cluster-admin role bound to application service account

    These are INTENTIONAL for demonstrating Wiz security scanning.
    DO NOT use this configuration in production!
  EOT
}

# kubectl configuration command
output "configure_kubectl" {
  description = "Command to configure kubectl for EKS"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"
}
