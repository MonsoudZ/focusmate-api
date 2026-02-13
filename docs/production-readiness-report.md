# Production Readiness Report

Date: 2026-02-05 09:55 EST
Repo: `intentia-api`

## Executive Status

This API is in a strong production-ready state after a focused hardening sweep.

Current quality gates are green:
- `bundle exec rspec` -> 1436 examples, 0 failures
- `bundle exec rubocop --no-server` -> 0 offenses
- `bundle exec brakeman -q` -> 0 warnings

## Scope Covered

Hardening window (latest commits):
- `b64d826` Tighten production runtime guardrails for Redis and Sidekiq
- `5e63e34` Make database health alerts resilient to Sentry outages
- `700be81` Harden refresh token transport to body/header only
- `8250616` Add per-user throttle for analytics app_opened
- `1e13e1c` Harden today query against invalid timezone data
- `efc634b` Harden list membership and invite deleted-list boundaries
- `cf82432` Enforce nested route integrity for tasks and invites
- `59ee43b` Limit sign_up to create-only API route
- `cf63908` Prune API auth and framework route surface
- `b44ffc3` Harden production health diagnostics exposure
- `2a8d520`, `bbe749f` auth cleanup indexes + refresh token churn controls

## What Was Hardened (Production Patterns)

- Route surface minimization
  - Removed unused API auth verbs/routes.
  - Removed unused framework route exposure (Active Storage route drawing disabled, Action Mailbox route surface pruned via framework loading choices).
- Auth/session boundary hardening
  - Refresh tokens accepted via request body or `X-Refresh-Token` header only.
  - Query-string refresh tokens ignored to reduce leakage risk in logs/proxies.
- Authorization and nested resource integrity
  - Nested list/task/subtask/membership/invite endpoints now enforce parent-child path integrity.
  - Deleted parent resources return `404` consistently.
- Operational endpoint protection
  - Health diagnostics endpoints protected by `HEALTH_DIAGNOSTICS_TOKEN`.
  - Sidekiq UI protected outside local envs with fail-closed auth behavior.
- Abuse/rate limiting
  - Password reset throttle corrected to actual route.
  - Invite accept throttled.
  - Per-user throttle added for analytics app-open events.
- Reliability and observability resilience
  - Sentry/reporting failures no longer fail critical health jobs.
  - One-time/TTL-protected logging around repeated observability failures.
- Performance/scalability
  - Query-shape indexes for auth cleanup and recurring-instance lookups.
  - Set-based orphaned assignment cleanup.
  - Performance guard tests added/expanded.

## Production Runtime Guardrails

Required production env vars (enforced at boot):
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `REDIS_URL`
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_BUNDLE_ID`
- `APNS_KEY_CONTENT`
- `APPLE_BUNDLE_ID`
- `HEALTH_DIAGNOSTICS_TOKEN`
- `SIDEKIQ_USERNAME`
- `SIDEKIQ_PASSWORD`

Process model:
- `web`: Puma (`Procfile`)
- `worker`: Sidekiq (`Procfile`)
- `release`: `bundle exec rails db:migrate`

Sidekiq schedule loading:
- YAML schedule parsing is now safe-loaded with error capture and non-crashing behavior.

## Staging/Prod Verification Runbook

1. Deploy with all required env vars configured.
2. Confirm release migration succeeds.
3. Confirm both `web` and `worker` processes are running.
4. Verify health endpoints:
   - `/health/live` and `/health/ready` are reachable by probes.
   - `/health/detailed` and `/health/metrics` require `X-Health-Token`.
5. Verify Sidekiq UI:
   - Requires configured credentials outside local env.
6. Smoke auth flows:
   - sign-up/sign-in/sign-out/refresh.
   - refresh via body and `X-Refresh-Token` header.
   - refresh token in query string is rejected.
7. Verify one protected nested-route mismatch case:
   - e.g. task from list A requested under list B returns `404`.
8. Tail logs for first 30-60 minutes:
   - watch for `sidekiq_cron_schedule_load_failed`, repeated auth errors, or elevated throttling.

## Residual Low-Risk Backlog

- Add a small `docs/ops-runbook.md` with incident playbooks (auth token incidents, Sidekiq backlog, health degradation).
- Add CI dependency/CVE scheduled scan if not already present.
- Add explicit SLO thresholds/alerts for Sidekiq queue depth and job latency.

## Recommendation

Proceed to production rollout under standard change control. The current state reflects professional Rails API production patterns: least-privilege route surface, fail-closed security gates, resilient background processing, and green static/dynamic quality checks.
