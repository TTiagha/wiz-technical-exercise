# =============================================================================
# EC2 MONGODB VM - Database Server
# =============================================================================
# This creates an EC2 instance running:
# - Ubuntu 20.04 LTS (intentionally outdated - EOL April 2025)
# - MongoDB 4.4 (intentionally outdated - EOL Feb 2024)
#
# INTENTIONAL WEAKNESSES:
# 1. Ubuntu 20.04 - missing security patches
# 2. MongoDB 4.4 - known CVEs exist
# 3. SSH exposed to internet (security group)
# 4. Overly permissive IAM role (ec2:*, s3:*)
#
# ATTACK CHAIN:
# Internet -> SSH -> Ubuntu exploit -> Root -> IAM creds -> AWS takeover
# =============================================================================

# Generate SSH key pair for VM access
resource "tls_private_key" "mongodb" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "mongodb" {
  key_name   = "${var.project_name}-mongodb-key"
  public_key = tls_private_key.mongodb.public_key_openssh

  tags = {
    Name = "${var.project_name}-mongodb-key"
  }
}

# Save private key to local file (for SSH access)
resource "local_file" "mongodb_key" {
  content         = tls_private_key.mongodb.private_key_pem
  filename        = "${path.module}/mongodb-key.pem"
  file_permission = "0400"
}

# MongoDB EC2 Instance
resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.ubuntu_20_04.id
  instance_type          = var.mongodb_instance_type
  key_name               = aws_key_pair.mongodb.key_name
  subnet_id              = aws_subnet.public[0].id  # PUBLIC subnet for SSH access
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb.name

  # Root volume
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false  # Not encrypting for simplicity (could be another finding)
  }

  # User data script to install MongoDB 4.4 and configure
  user_data = base64encode(templatefile("${path.module}/templates/mongodb_userdata.sh", {
    mongodb_password = var.mongodb_password
    s3_bucket        = aws_s3_bucket.backups.id
    aws_region       = var.aws_region
  }))

  tags = {
    Name        = "${var.project_name}-mongodb"
    Application = "MongoDB"
    Version     = "4.4-EOL"
    Warning     = "INTENTIONALLY-VULNERABLE"
  }

  # Wait for IAM instance profile to be ready
  depends_on = [aws_iam_instance_profile.mongodb]
}

# Elastic IP for MongoDB (static public IP)
resource "aws_eip" "mongodb" {
  instance = aws_instance.mongodb.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-mongodb-eip"
  }
}
