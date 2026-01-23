# =============================================================================
# SECURE S3 BUCKET CONFIGURATION
# =============================================================================
# Compare to: ../s3.tf (intentionally public)
# This file is DOCUMENTATION ONLY - not deployed
# Shows before/after for interview discussion
# =============================================================================

# SECURE: Private bucket with encryption
resource "aws_s3_bucket" "backups_secure" {
  bucket = "${var.project_name}-backups-secure-${random_id.suffix.hex}"

  tags = {
    Name        = "${var.project_name}-backups-secure"
    Environment = "production"
    Security    = "PRIVATE"
  }
}

# SECURE: Block ALL public access
# BEFORE: All four were "false" (allowing public access)
# AFTER:  All four are "true" (blocking public access)
resource "aws_s3_bucket_public_access_block" "backups_secure" {
  bucket = aws_s3_bucket.backups_secure.id

  block_public_acls       = true   # FIXED: Was false
  block_public_policy     = true   # FIXED: Was false
  ignore_public_acls      = true   # FIXED: Was false
  restrict_public_buckets = true   # FIXED: Was false
}

# SECURE: Enable server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "backups_secure" {
  bucket = aws_s3_bucket.backups_secure.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.backups.arn
    }
    bucket_key_enabled = true
  }
}

# SECURE: KMS key for bucket encryption
resource "aws_kms_key" "backups" {
  description             = "KMS key for MongoDB backup encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-backups-kms"
  }
}

# SECURE: Bucket policy allows ONLY the specific MongoDB backup role
# BEFORE: Principal = "*" (anyone on the internet)
# AFTER:  Principal = specific IAM role ARN
resource "aws_s3_bucket_policy" "backups_secure" {
  bucket = aws_s3_bucket.backups_secure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowOnlyMongoDBBackupRole"
        Effect    = "Allow"
        Principal = {
          AWS = aws_iam_role.mongodb_secure.arn  # FIXED: Specific role, not "*"
        }
        Action = [
          "s3:PutObject"  # FIXED: Only PutObject, not GetObject/ListBucket
        ]
        Resource = "${aws_s3_bucket.backups_secure.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.backups_secure.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      }
    ]
  })
}

# SECURE: Enable versioning for backup recovery
resource "aws_s3_bucket_versioning" "backups_secure" {
  bucket = aws_s3_bucket.backups_secure.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SECURE: Lifecycle policy to manage costs
resource "aws_s3_bucket_lifecycle_configuration" "backups_secure" {
  bucket = aws_s3_bucket.backups_secure.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    # Move to Glacier after 30 days
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # Delete after 90 days
    expiration {
      days = 90
    }

    # Clean up old versions
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# =============================================================================
# COMPARISON SUMMARY
# =============================================================================
#
# | Aspect          | BEFORE (Vulnerable)           | AFTER (Secure)                |
# |-----------------|-------------------------------|-------------------------------|
# | Public Access   | All blocks set to "false"     | All blocks set to "true"      |
# | Bucket Policy   | Principal: "*"                | Principal: specific role ARN  |
# | Actions Allowed | GetObject, ListBucket, etc.   | PutObject only                |
# | Encryption      | None                          | KMS with key rotation         |
# | Versioning      | Disabled                      | Enabled                       |
# | Lifecycle       | None                          | 90-day retention              |
#
# =============================================================================
