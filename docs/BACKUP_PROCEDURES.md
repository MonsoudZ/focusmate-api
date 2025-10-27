# Database Backup Procedures

## Automated Backups

### Production Database Backups
- **Frequency**: Daily at 2 AM UTC
- **Retention**: 30 days
- **Location**: S3 bucket `focusmate-api-backups`
- **Format**: PostgreSQL custom format (.dump)

### Backup Script
```bash
#!/bin/bash
# /opt/backup/db_backup.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="focusmate_api_production_${DATE}.dump"
S3_BUCKET="focusmate-api-backups"

# Create backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME -Fc -f /tmp/$BACKUP_FILE

# Upload to S3
aws s3 cp /tmp/$BACKUP_FILE s3://$S3_BUCKET/daily/$BACKUP_FILE

# Cleanup local file
rm /tmp/$BACKUP_FILE

# Remove old backups (keep 30 days)
aws s3 ls s3://$S3_BUCKET/daily/ | awk '$1 < "'$(date -d '30 days ago' '+%Y-%m-%d')'" {print $4}' | xargs -I {} aws s3 rm s3://$S3_BUCKET/daily/{}
```

### Restore Procedure

#### 1. Emergency Restore (Full Database)
```bash
# Download backup from S3
aws s3 cp s3://focusmate-api-backups/daily/focusmate_api_production_YYYYMMDD_HHMMSS.dump /tmp/restore.dump

# Stop application
sudo systemctl stop focusmate-api

# Drop and recreate database
sudo -u postgres dropdb focusmate_api_production
sudo -u postgres createdb focusmate_api_production

# Restore from backup
pg_restore -h localhost -U focusmate_api -d focusmate_api_production /tmp/restore.dump

# Start application
sudo systemctl start focusmate-api
```

#### 2. Point-in-Time Recovery
```bash
# Restore to specific timestamp
pg_restore -h localhost -U focusmate_api -d focusmate_api_production \
  --clean --if-exists \
  /tmp/restore.dump
```

#### 3. Test Restore (Staging)
```bash
# Create test database
sudo -u postgres createdb focusmate_api_staging

# Restore to staging
pg_restore -h localhost -U focusmate_api -d focusmate_api_staging /tmp/restore.dump

# Run tests
RAILS_ENV=staging bundle exec rails db:migrate
RAILS_ENV=staging bundle exec rspec
```

## Monitoring

### Backup Verification
- Daily backup size monitoring
- Backup completion alerts via Sentry
- Weekly restore test in staging environment

### Alert Thresholds
- Backup size < 10MB (potential issue)
- Backup age > 25 hours (backup failed)
- Restore test failure

## Recovery Time Objectives (RTO)
- **Full restore**: < 15 minutes
- **Point-in-time recovery**: < 30 minutes
- **Staging test restore**: < 5 minutes

## Recovery Point Objectives (RPO)
- **Maximum data loss**: 24 hours (daily backups)
- **Critical data**: 1 hour (WAL archiving for critical tables)
