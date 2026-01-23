# =============================================================================
# VARIABLES - Input Parameters for the Wiz Technical Exercise
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "wiz-exercise"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (65,536 IPs)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (for EKS)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "mongodb_instance_type" {
  description = "Instance type for MongoDB VM"
  type        = string
  default     = "t3.small"
}

variable "eks_node_instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_desired_capacity" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "mongodb_password" {
  description = "Password for MongoDB admin user"
  type        = string
  sensitive   = true
  default     = "WizExercise2024!"  # For demo purposes - NEVER do this in production
}

variable "candidate_name" {
  description = "Candidate name for wizexercise.txt file"
  type        = string
  default     = "Tem Muya Tiagha"
}
