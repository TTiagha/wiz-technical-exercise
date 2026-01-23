#!/bin/bash
# =============================================================================
# MongoDB Backup Script
# =============================================================================
# This script creates MongoDB backups and uploads them to S3.
# NOTE: The S3 bucket is INTENTIONALLY PUBLIC for the security exercise.
# =============================================================================

set -e

# Configuration (set these via environment or hardcode for demo)
MONGODB_URI="${MONGODB_URI:-mongodb://admin:WizExercise2024!@localhost:27017}"
S3_BUCKET="${S3_BUCKET:-wiz-exercise-backups}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/mongodb_backup_${TIMESTAMP}.archive"

echo "Starting MongoDB backup at $(date)"

# Create backup archive
echo "Creating backup archive..."
mongodump --uri="$MONGODB_URI" --archive="$BACKUP_FILE" --authenticationDatabase=admin

# Upload to S3
echo "Uploading to S3 bucket: $S3_BUCKET"
aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/backups/mongodb_backup_${TIMESTAMP}.archive" --region "$AWS_REGION"

# Cleanup local file
rm -f "$BACKUP_FILE"

echo "Backup completed successfully: mongodb_backup_${TIMESTAMP}.archive"
echo "Finished at $(date)"
