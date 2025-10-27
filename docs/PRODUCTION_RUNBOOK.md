# FocusMate API Production Runbook

## Quick Reference
- **Application**: FocusMate API (Rails 8.0.3)
- **Environment**: Production
- **Deployment**: Kamal
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Monitoring**: Sentry + Lograge

## Deployment Procedures

### Deploy to Production
```bash
# 1. Pre-deployment checks
bundle exec rails db:migrate:status
bundle exec brakeman -q -w2
bundle exec rspec

# 2. Deploy with Kamal
bundle exec kamal deploy

# 3. Post-deployment verification
curl -f https://api.focusmate.com/health/live
curl -f https://api.focusmate.com/health/ready
```

### Rollback Procedure
```bash
# 1. Rollback to previous version
bundle exec kamal rollback

# 2. Verify rollback
curl -f https://api.focusmate.com/health/live
curl -f https://api.focusmate.com/health/ready

# 3. Check application logs
bundle exec kamal app logs --lines 100
```

## Health Checks

### Application Health
- **Live**: `GET /health/live` → 200 OK
- **Ready**: `GET /health/ready` → 200 OK with service checks

### Service Dependencies
- **Database**: PostgreSQL connection active
- **Redis**: Ping response = 'PONG'
- **Sidekiq**: Redis info available

## Common Alarms & Responses

### High Response Time (>2s)
**Symptoms**: API responses slow, user complaints
**Response**:
1. Check `bundle exec kamal app logs --lines 50`
2. Check database connection pool: `bundle exec rails runner "puts ActiveRecord::Base.connection_pool.stat"`
3. Check Redis: `bundle exec rails runner "puts Redis.new.info"`
4. Scale up if needed: `bundle exec kamal scale app 2`

### Database Connection Errors
**Symptoms**: 500 errors, "connection pool exhausted"
**Response**:
1. Check database status: `bundle exec rails runner "puts ActiveRecord::Base.connection.active?"`
2. Check connection pool: `bundle exec rails runner "puts ActiveRecord::Base.connection_pool.stat"`
3. Restart application: `bundle exec kamal app restart`
4. If persistent, check database server

### High Error Rate (>5%)
**Symptoms**: Sentry alerts, 500 errors
**Response**:
1. Check Sentry dashboard for error patterns
2. Check application logs: `bundle exec kamal app logs --lines 100`
3. Check for memory issues: `bundle exec kamal app exec "free -h"`
4. Restart if needed: `bundle exec kamal app restart`

### Sidekiq Queue Backlog
**Symptoms**: Jobs not processing, queue growing
**Response**:
1. Check Sidekiq web UI: `bundle exec kamal app exec "bundle exec sidekiq-web"`
2. Check Redis: `bundle exec rails runner "puts Sidekiq::Queue.new.size"`
3. Restart Sidekiq: `bundle exec kamal app exec "bundle exec sidekiq"`
4. Check for dead jobs: `bundle exec rails runner "puts Sidekiq::DeadSet.new.size"`

### Memory Usage High (>80%)
**Symptoms**: Slow responses, OOM errors
**Response**:
1. Check memory: `bundle exec kamal app exec "free -h"`
2. Check for memory leaks: `bundle exec kamal app exec "ps aux --sort=-%mem"`
3. Restart application: `bundle exec kamal app restart`
4. Scale up if needed: `bundle exec kamal scale app 2`

## Emergency Procedures

### Complete Service Outage
1. Check infrastructure: `bundle exec kamal details`
2. Check database: `bundle exec kamal app exec "pg_isready"`
3. Check Redis: `bundle exec kamal app exec "redis-cli ping"`
4. Restart all services: `bundle exec kamal app restart`
5. If still down, rollback: `bundle exec kamal rollback`

### Data Corruption
1. Stop application: `bundle exec kamal app stop`
2. Restore from backup: See BACKUP_PROCEDURES.md
3. Verify data integrity
4. Start application: `bundle exec kamal app start`

### Security Incident
1. Check logs for suspicious activity
2. Block suspicious IPs in Rack::Attack
3. Rotate secrets if compromised
4. Notify security team

## Monitoring & Alerts

### Key Metrics
- Response time (P95 < 300ms)
- Error rate (< 1%)
- Memory usage (< 80%)
- Database connections (< 80% of pool)
- Queue size (< 1000 jobs)

### Alert Channels
- **Critical**: PagerDuty
- **Warning**: Slack #alerts
- **Info**: Email notifications

### Log Locations
- **Application**: `bundle exec kamal app logs`
- **Database**: PostgreSQL logs
- **Redis**: Redis logs
- **System**: `/var/log/syslog`

## Contact Information
- **On-call**: Check PagerDuty
- **DevOps**: Slack #devops
- **Database**: Slack #database
- **Security**: security@focusmate.com
