# =============================================================================
# WIZ TECHNICAL EXERCISE - MAIN TERRAFORM CONFIGURATION
# =============================================================================
# This creates intentionally vulnerable infrastructure for security training
# DO NOT use this configuration in production environments
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "wiz-technical-exercise"
      Environment = "training"
      ManagedBy   = "terraform"
      Owner       = "tem-muya-tiagha"
      Warning     = "INTENTIONALLY-VULNERABLE"
    }
  }
}

# Generate random suffix for globally unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Get the latest Ubuntu 20.04 AMI (intentionally outdated for exercise)
data "aws_ami" "ubuntu_20_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
