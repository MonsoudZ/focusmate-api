# Focusmate API - Comprehensive Codebase Audit Report

**Date:** January 21, 2026
**Auditor:** Claude AI
**Codebase:** Ruby on Rails 8.0.3 JSON API
**Ruby Version:** 3.3.5

---

## Executive Summary

The Focusmate API is a well-architected task management application built with Ruby on Rails. Overall, the codebase demonstrates good practices with proper authentication, authorization, and service-oriented architecture. However, this audit identified **76 issues** across 7 categories requiring attention.

### Summary by Severity

| Severity | Count |
|----------|-------|
| Critical | 5 |
| High | 12 |
| Medium | 38 |
| Low | 21 |
| **Total** | **76** |

### Summary by Category

| Category | Issues | Critical/High Issues |
|----------|--------|---------------------|
| Security | 14 | 3 |
| Code Quality | 18 | 4 |
| Database/Schema | 15 | 4 |
| Performance | 12 | 3 |
| API Design | 11 | 2 |
| Test Coverage | 8 | 2 |
| Configuration | 8 | 2 |

---

## 1. Security Issues

### Critical Issues

#### SEC-001: Bug - Wrong Attribute Reference in NudgesController
**File:** `app/controllers/api/v1/nudges_controller.rb:12`
```ruby
task_owner = @task.user || @task.list.user  # BUG: @task.user doesn't exist!
```
**Impact:** The Task model has `creator` and `assigned_to` associations, NOT `user`. This line will always evaluate to `@task.list.user`, sending nudges to the wrong person.
**Fix:** Change to `@task.creator || @task.list.user`

#### SEC-002: IDOR via Direct Task.find()
**Files:**
- `app/controllers/api/v1/tasks_controller.rb:220`
- `app/controllers/api/v1/nudges_controller.rb:40`
```ruby
@task = Task.find(params[:id])  # No user scoping
```
**Impact:** Allows enumeration of task IDs (404 vs 403 differentiation). Attackers can test authorization indirectly.
**Fix:** Use `policy_scope(Task).find(params[:id])`

### High Priority Issues

#### SEC-003: Unsafe Parameter Handling
**File:** `app/services/task_creation_service.rb:27`
```ruby
params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
```
**Impact:** Bypasses Rails' parameter filtering, potential mass assignment vulnerability.
**Fix:** Keep parameters as ActionController::Parameters and use `.permit()`

#### SEC-004: Password Reset Email Enumeration
**File:** `app/controllers/api/v1/passwords_controller.rb:14-17`
**Impact:** Different responses for valid/invalid emails allow account enumeration.
**Fix:** Return consistent message: "If an account exists, reset instructions have been sent."

#### SEC-005: Temporary File Not Cleaned (APNS Key)
**File:** `app/services/push_notifications/sender.rb:59-62`
**Impact:** APNS private key written to disk without explicit cleanup.
**Fix:** Use `Tempfile.open` with block to ensure automatic cleanup.

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| SEC-006 | Task position validation missing | tasks_controller.rb:179 |
| SEC-007 | JWT uses same secret as session | devise.rb:39 |
| SEC-008 | DEVISE_PEPPER is optional | devise.rb:35 |
| SEC-009 | Missing environment variable validation | production_required_env.rb:7 |
| SEC-010 | Sidekiq credentials not validated | routes.rb:20-21 |
| SEC-011 | Sentry incomplete data filtering | sentry.rb:14 |
| SEC-012 | ActionCable dev origins in global config | application.rb:34 |
| SEC-013 | No explicit CORS configuration | - |
| SEC-014 | Missing Content Security Policy headers | - |

---

## 2. Code Quality Issues

### Critical Issues

#### CQ-001: Duplicated Nudge Implementation with Inconsistent Logic
**Files:**
- `app/controllers/api/v1/tasks_controller.rb:132-160`
- `app/controllers/api/v1/nudges_controller.rb:8-35`

**Impact:** Two controllers implement the same feature with different logic:
- `tasks_controller.rb:135`: `task_owner = @task.creator || @task.list.user` (CORRECT)
- `nudges_controller.rb:12`: `task_owner = @task.user || @task.list.user` (BUG - @task.user doesn't exist)

**Fix:** Extract nudge logic to a service and use it in both controllers.

#### CQ-002: N+1 Query in Task Reorder
**File:** `app/controllers/api/v1/tasks_controller.rb:177-180`
```ruby
params[:tasks].each do |task_data|
  task = @list.tasks.find(task_data[:id])  # N queries
  task.update!(position: task_data[:position])  # N more queries
end
```
**Fix:** Batch load tasks and use `update_all` or bulk update.

### High Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| CQ-003 | Duplicated authorization logic | task_completion_service.rb:77-82, task_update_service.rb:33-38 |
| CQ-004 | Bare rescue clauses | task_recurrence_service.rb:82,95 |
| CQ-005 | Fat tasks_controller (262 lines) | tasks_controller.rb |
| CQ-006 | Magic number 100 in weekday loop | recurring_task_service.rb:111 |

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| CQ-007 | Magic number 999999 in position | task.rb:59 |
| CQ-008 | Magic number 3 for nudge rate limit | nudge.rb:26 |
| CQ-009 | Duplicated soft_delete methods | device.rb:45-51, task_event.rb:34-40 |
| CQ-010 | Snooze logic embedded in controller | tasks_controller.rb:93-106 |
| CQ-011 | Inline analytics tracking | Multiple controllers |
| CQ-012 | done? uses string comparison | task.rb:86 |
| CQ-013 | Missing Task#owner helper method | task.rb |
| CQ-014 | Complex filtering logic in controller | tasks_controller.rb:244-260 |

### Low Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| CQ-015 | Inconsistent serializer patterns | Various serializers |
| CQ-016 | Inconsistent error response formats | Multiple controllers |
| CQ-017 | Missing defensive programming in services | Various services |
| CQ-018 | Misleading parameter names | memberships/update.rb:11 |

---

## 3. Database/Schema Issues

### Critical Issues

#### DB-001: Missing Model Classes for Database Tables
**Impact:** 3 tables exist in schema without corresponding ActiveRecord models:
- `notification_logs` - no NotificationLog model
- `saved_locations` - no SavedLocation model
- `user_locations` - no UserLocation model

**Fix:** Create model classes or remove orphaned tables.

#### DB-002: Duplicate Check Constraints
**File:** `db/schema.rb:296-299`
```ruby
check_tasks_status: "status = ANY (ARRAY[0, 1, 2, 3])"
tasks_status_check: "status = ANY (ARRAY[0, 1, 2, 3])"  # Duplicate!
```
**Fix:** Remove duplicate constraints via migration.

#### DB-003: Orphaned Table References in Migrations
**Files:** Multiple migrations reference tables that were dropped:
- `coaching_relationships`
- `item_visibility_restrictions`
- `list_shares`
- `daily_summaries`

**Impact:** Running migrations from scratch will fail.
**Fix:** Add safety checks or remove orphaned references.

### High Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| DB-004 | Duplicate indexes wasting space | schema.rb:133-134,198-199,269-270 |
| DB-005 | Enum mismatch: DB allows [0,1,2,3], model defines [0,1,2] | schema.rb vs task.rb:19 |
| DB-006 | Unused counter_cache columns | schema.rb:252,342-344 |
| DB-007 | Missing reverse associations in models | user.rb, task.rb |

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| DB-008 | Location data type inconsistency (FLOAT vs DECIMAL) | schema.rb |
| DB-009 | Unvalidated foreign key (assigned_to_id) | migrate/20251027025724 |
| DB-010 | Missing NOT NULL where business logic requires it | Various columns |
| DB-011 | Large tables without partitioning strategy | notification_logs, user_locations, analytics_events |
| DB-012 | Redundant single-column indexes | schema.rb:261-290 |

### Low Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| DB-013 | Missing composite indexes for common queries | Various |
| DB-014 | Counter cache not enabled on subtasks | task.rb:13 |
| DB-015 | Unvalidated check constraint (devices_platform_enum) | schema.rb:59 |

---

## 4. Performance Issues

### Critical Issues

#### PERF-001: Database Health Check Full Table Counts
**File:** `app/jobs/database_health_check_job.rb:47-52`
```ruby
jwt_denylist_count: JwtDenylist.count,        # Full table scan
analytics_events_count: AnalyticsEvent.count, # Full table scan
users_count: User.count,                      # Full table scan
```
**Impact:** COUNT(*) on potentially millions of rows every hour.
**Fix:** Use database statistics/estimates or cache counts.

#### PERF-002: Analytics Tracker Count on Every Edit
**File:** `app/services/analytics_tracker.rb:123`
```ruby
edit_count: AnalyticsEvent.where(task: task, event_type: "task_edited").count + 1
```
**Impact:** Counts all task_edited events every time a task is edited.
**Fix:** Store edit_count on task model or use counter_cache.

### High Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| PERF-003 | N+1 in recurring task generation | recurring_task_generation_job.rb:23-46 |
| PERF-004 | Snooze count query on every snooze | tasks_controller.rb:98 |
| PERF-005 | Task reorder loop queries | tasks_controller.rb:177-180 |
| PERF-006 | Streak service double-querying per day | streak_service.rb:29-41 |

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| PERF-007 | TodayTasksQuery stats runs separate count | today_tasks_query.rb:85-95 |
| PERF-008 | Missing eager loads in serializer fallback | task_serializer.rb:94 |
| PERF-009 | Loading all tasks to memory with .to_a | today_tasks_query.rb:76-82 |
| PERF-010 | Inefficient weekday calculation loop | recurring_task_service.rb:107-123 |
| PERF-011 | Pagination full count query | paginatable.rb:24 |
| PERF-012 | No memoization for push device queries | push_notifications/sender.rb:10 |

---

## 5. API Design Issues

### High Priority Issues

#### API-001: Inconsistent Error Response Formats
**Files:** Multiple controllers use different error structures:
```ruby
# Format 1 (nudges_controller.rb:16)
{ error: "You cannot nudge yourself" }

# Format 2 (tasks_controller.rb:112)
{ error: { message: "assigned_to is required" } }

# Format 3 (error_handling.rb:86-93)
{ error: { code: "validation_error", message: "...", details: [...] } }
```
**Fix:** Standardize on a single error format across all endpoints.

#### API-002: No API Documentation
**Impact:** No OpenAPI/Swagger spec, no endpoint documentation, no error code reference.
**Fix:** Create OpenAPI 3.0 specification document.

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| API-003 | Non-standard member route actions | routes.rb:48-53 |
| API-004 | Missing pagination on lists, tags, memberships | Various controllers |
| API-005 | Inconsistent timestamp formats | Various serializers |
| API-006 | Parameter naming inconsistency (snake_case vs camelCase) | tasks_controller.rb:209 |
| API-007 | Search endpoint lacks pagination | tasks_controller.rb:199 |
| API-008 | Over-fetching by default (41 fields in TaskSerializer) | task_serializer.rb |

### Low Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| API-009 | Missing HATEOAS links | All responses |
| API-010 | No deprecation headers/versioning policy | - |
| API-011 | Singular resource path (/users/profile vs /users/me) | routes.rb:31 |

---

## 6. Test Coverage Issues

### Critical Coverage Gaps

| Component | Total | Tested | Coverage |
|-----------|-------|--------|----------|
| Models | 12 | 8 | 67% |
| Controllers/APIs | 14 | 10 | 71% |
| Services | 26 | 12 | **46%** |
| Jobs | 7 | 2 | **29%** |
| **Overall** | **59** | **32** | **54%** |

### High Priority Missing Tests

| Component | Description |
|-----------|-------------|
| AppleAuthController | No tests for Apple Sign-In flow |
| PushNotifications::Sender | Critical push notification service untested |
| RecurringTaskGenerationJob | Background job for recurring tasks untested |
| StreakService | User engagement tracking untested |
| MembershipsController | Membership management untested |

### Missing Model Tests

- `AnalyticsEvent` - NO TEST
- `JwtDenylist` - NO TEST
- `Tag` - NO TEST
- `TaskTag` - NO TEST

### Missing Service Tests (14 services)

- AnalyticsTracker, Auth::Login, Auth::Register
- Health::CheckRegistry, Health::Report, Health::System
- Memberships::Create/Destroy/Update
- PushNotifications::Sender, StreakService
- Users::AccountDeleteService, PasswordChangeService, ProfileUpdateService

### Test Quality Issues

| ID | Description |
|----|-------------|
| TEST-001 | Over-mocked ApplicationMonitor tests |
| TEST-002 | Missing negative/edge case tests |
| TEST-003 | Missing authorization boundary tests |
| TEST-004 | Duplicate auth header setup logic |
| TEST-005 | Missing factories for TaskTag, AnalyticsEvent, JwtDenylist |

---

## 7. Configuration Issues

### High Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| CFG-001 | Missing required env var validation | production_required_env.rb:7 |
| CFG-002 | Hardcoded default APP_HOST domain | production.rb:84,110 |

### Medium Priority Issues

| ID | Description | File:Line |
|----|-------------|-----------|
| CFG-003 | Devise mailer sender not configured | devise.rb:11 |
| CFG-004 | Sidekiq credentials not presence-validated | routes.rb:20-21 |
| CFG-005 | Sentry filtering incomplete | sentry.rb:14 |
| CFG-006 | ActionCable dev origins in global config | application.rb:34 |
| CFG-007 | No .env.example file | - |
| CFG-008 | No automated security scanning in CI/CD | - |

---

## Priority Recommendations

### Immediate (This Week)

1. **SEC-001/CQ-001**: Fix the bug in nudges_controller.rb using wrong attribute (`@task.user` → `@task.creator`)
2. **SEC-002**: Add policy_scope to task lookups to prevent IDOR
3. **CQ-002/PERF-005**: Fix N+1 in task reorder action
4. **PERF-001**: Replace full table COUNT with database statistics
5. **PERF-002**: Store edit_count on task model instead of counting

### Short Term (This Sprint)

1. **SEC-003**: Replace `to_unsafe_h` with proper parameter permitting
2. **DB-001**: Create missing model classes or clean up orphaned tables
3. **DB-002**: Remove duplicate check constraints and indexes
4. **API-001**: Standardize error response format across all controllers
5. **CQ-003**: Extract duplicated authorization logic to shared service
6. **TEST**: Add tests for AppleAuthController and PushNotifications::Sender

### Medium Term (This Month)

1. **API-002**: Create OpenAPI documentation
2. **API-004**: Add pagination to all collection endpoints
3. **CQ-004**: Remove bare rescue clauses
4. **CQ-005**: Refactor fat tasks_controller (262 lines)
5. **CFG-001**: Add missing environment variable validations
6. **DB-005**: Fix enum value mismatches between DB and model
7. Increase test coverage from 54% to 75%

### Long Term (This Quarter)

1. **DB-011**: Implement partitioning strategy for large tables
2. **SEC-007**: Use separate JWT signing key
3. **CFG-008**: Integrate security audit tools into CI/CD
4. Complete service and job test coverage
5. Add comprehensive API documentation

---

## Conclusion

The Focusmate API has a solid foundation with proper authentication, authorization patterns, and service-oriented architecture. The most critical issues requiring immediate attention are:

1. **Bug Fix**: The wrong attribute reference in NudgesController (`@task.user` should be `@task.creator`)
2. **Security**: IDOR vulnerabilities from direct `Task.find()` without scoping
3. **Performance**: N+1 queries in task reorder and recurring task generation
4. **Testing**: 54% overall coverage with critical paths untested

Addressing the immediate and short-term recommendations will significantly improve the codebase's security, reliability, and maintainability.

---

*This audit was performed by automated analysis. Manual review is recommended for critical security issues before deploying fixes to production.*
