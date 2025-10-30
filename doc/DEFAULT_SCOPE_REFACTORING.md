# Default Scope Refactoring Guide

## Current State

The following models use `default_scope { where(deleted_at: nil) }` for soft-deletion:

1. `Task` - Already has `not_deleted` scope
2. `List`
3. `SavedLocation`
4. `UserLocation`
5. `Device`
6. `TaskEvent`
7. `DailySummary`
8. `NotificationLog`
9. `ItemVisibilityRestriction`

All models have `with_deleted` scopes to access deleted records when needed.

## Why Refactor?

`default_scope` is considered an anti-pattern in Rails because:

1. **Implicit Behavior**: Queries are filtered without being obvious in the code
2. **Association Issues**: Can cause unexpected results with joins and associations
3. **Debugging Difficulty**: Hard to track down why certain records aren't appearing
4. **Override Complexity**: Requires `unscoped` or `with_deleted` to access all records

## Recommended Approach

Replace `default_scope` with explicit scopes:

```ruby
# Instead of:
default_scope { where(deleted_at: nil) }

# Use:
scope :not_deleted, -> { where(deleted_at: nil) }

# Then update all queries to use:
Task.not_deleted.where(...)
```

## Migration Strategy

### Phase 1: Add explicit scopes (if not present)
- Add `not_deleted` scope to all models
- Ensure `with_deleted` scopes exist

### Phase 2: Update controllers and services
- Replace all model queries with `.not_deleted`
- Example: `Task.where(...)` → `Task.not_deleted.where(...)`
- This is a large change affecting ~100+ query locations

### Phase 3: Update associations
- Add `-> { not_deleted }` to associations
- Example: `has_many :tasks, -> { not_deleted }`

### Phase 4: Remove default_scope
- Remove `default_scope` from models
- Run full test suite to verify

### Phase 5: Verify production behavior
- Deploy to staging
- Monitor for any unexpected query results
- Roll out to production carefully

## Estimated Effort

- **Small**: 2-3 hours per model
- **Total**: 20-30 hours for all 9 models
- **Risk**: HIGH - touches core querying logic throughout app

## Alternative: Keep default_scope

Given the risk and effort, keeping `default_scope` is acceptable if:
- The team is aware of the gotchas
- Tests cover edge cases well (currently 1344 passing tests)
- `with_deleted` is used consistently when needed

## Decision

**Status**: Documented for future consideration
**Reason**: High risk/effort for marginal benefit given current test coverage
**Recommendation**: Address when doing major refactoring or if bugs arise

---

**Last Updated**: 2025-10-30
**Documented By**: Code Audit Process
