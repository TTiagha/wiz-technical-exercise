# =============================================================================
# S3 BUCKET - Database Backups (INTENTIONALLY PUBLIC)
# =============================================================================
# This S3 bucket is INTENTIONALLY configured with public access.
#
# WHY THIS IS DANGEROUS:
# - Principal = "*" means ANY person/system on the internet
# - s3:ListBucket lets attackers see what files exist
# - s3:GetObject lets attackers download any file
# - Database backups contain ALL data including credentials
#
# RISK ASSESSMENT:
# - Isolated Risk: CRITICAL (even without other findings)
# - Chained Risk: CATASTROPHIC when backup contains MongoDB creds
#
# CORRECT PRACTICE:
# - Block all public access
# - Use bucket policies to allow only specific IAM roles
# - Enable encryption at rest
# - Enable versioning for recovery
# =============================================================================

resource "aws_s3_bucket" "backups" {
  bucket = "${var.project_name}-backups-${random_id.suffix.hex}"

  # Force destroy allows terraform to delete bucket even with objects
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-backups"
    Environment = "exercise"
    Purpose     = "MongoDB backups - INTENTIONALLY PUBLIC"
    Warning     = "PUBLIC-ACCESS-ENABLED"
  }
}

# INTENTIONAL WEAKNESS: Disable all public access blocks
resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  # All of these should be TRUE in production
  block_public_acls       = false  # WEAKNESS: Allows public ACLs
  block_public_policy     = false  # WEAKNESS: Allows public bucket policies
  ignore_public_acls      = false  # WEAKNESS: Respects public ACLs
  restrict_public_buckets = false  # WEAKNESS: Allows public bucket policies
}

# INTENTIONAL WEAKNESS: Public read policy
resource "aws_s3_bucket_policy" "backups_public" {
  bucket = aws_s3_bucket.backups.id

  # Must wait for public access block to be configured first
  depends_on = [aws_s3_bucket_public_access_block.backups]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadAccess"
      Effect    = "Allow"
      Principal = "*"  # CRITICAL: Anyone on the internet!
      Action = [
        "s3:GetObject",    # Download any file
        "s3:ListBucket"    # List all files in bucket
      ]
      Resource = [
        aws_s3_bucket.backups.arn,         # Bucket itself (for ListBucket)
        "${aws_s3_bucket.backups.arn}/*"   # All objects (for GetObject)
      ]
    }]
  })
}

# Enable versioning (good practice even for demo)
resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle rule to delete old backups after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "cleanup-old-backups"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    expiration {
      days = 7
    }
  }
}
