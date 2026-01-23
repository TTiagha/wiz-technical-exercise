#!/bin/bash
# =============================================================================
# MongoDB 4.4 Installation Script (INTENTIONALLY OUTDATED VERSION)
# =============================================================================
# This script installs MongoDB 4.4 which reached EOL in February 2024
# Known vulnerabilities exist in this version
# =============================================================================

set -e

# Update system packages
apt-get update

# Install prerequisites
apt-get install -y gnupg curl awscli

# Add MongoDB 4.4 repository (INTENTIONALLY OUTDATED)
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Update and install MongoDB 4.4
apt-get update
apt-get install -y mongodb-org

# Configure MongoDB to listen on all interfaces within VPC
cat > /etc/mongod.conf << 'EOF'
# MongoDB 4.4 Configuration
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 0.0.0.0  # Listen on all interfaces (within VPC via security group)

security:
  authorization: enabled

EOF

# Start and enable MongoDB
systemctl start mongod
systemctl enable mongod

# Wait for MongoDB to be ready
sleep 10

# Create admin user
mongosh admin --eval '
db.createUser({
  user: "admin",
  pwd: "${mongodb_password}",
  roles: [ { role: "userAdminAnyDatabase", db: "admin" }, "readWriteAnyDatabase" ]
});
'

# Create application user for todos database
mongosh admin -u admin -p '${mongodb_password}' --eval '
use todos;
db.createUser({
  user: "todoapp",
  pwd: "${mongodb_password}",
  roles: [ { role: "readWrite", db: "todos" } ]
});
'

# Initialize todos collection with a sample document
mongosh todos -u todoapp -p '${mongodb_password}' --authenticationDatabase todos --eval '
db.todos.insertOne({
  text: "Welcome to the Wiz Technical Exercise!",
  completed: false,
  createdAt: new Date()
});
'

# Create backup script
cat > /opt/mongo-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
# MongoDB Backup Script - Uploads to PUBLIC S3 bucket (INTENTIONAL WEAKNESS)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/tmp/mongodb_backup_$TIMESTAMP.archive"

# Create backup archive
mongodump --uri="mongodb://admin:${mongodb_password}@localhost:27017" --archive="$BACKUP_FILE" --authenticationDatabase=admin

# Upload to S3 (PUBLIC bucket - INTENTIONAL WEAKNESS)
aws s3 cp "$BACKUP_FILE" "s3://${s3_bucket}/backups/mongodb_backup_$TIMESTAMP.archive" --region ${aws_region}

# Cleanup local file
rm -f "$BACKUP_FILE"

echo "Backup completed: mongodb_backup_$TIMESTAMP.archive"
BACKUP_SCRIPT

chmod +x /opt/mongo-backup.sh

# Set up cron job for daily backups at 2am
echo "0 2 * * * root /opt/mongo-backup.sh >> /var/log/mongo-backup.log 2>&1" > /etc/cron.d/mongo-backup

# Run initial backup
/opt/mongo-backup.sh

# Create a marker file to indicate successful setup
echo "MongoDB 4.4 setup completed at $(date)" > /var/log/mongodb-setup-complete.txt

# Log the MongoDB version for verification
mongod --version >> /var/log/mongodb-setup-complete.txt
