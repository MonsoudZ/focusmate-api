# frozen_string_literal: true

class JwtCleanupJob < ApplicationJob
  queue_as :maintenance
  DELETE_BATCH_SIZE = ENV.fetch("JWT_CLEANUP_BATCH_SIZE", 1_000).to_i
  ACTIVE_FAMILY_REVOKED_RETENTION_DAYS = ENV.fetch("REFRESH_ACTIVE_FAMILY_REVOKED_DAYS", 7).to_i
  INACTIVE_FAMILY_RETENTION_DAYS = ENV.fetch("REFRESH_INACTIVE_FAMILY_DAYS", 3).to_i

  # Run daily to clean up expired JWT tokens from the denylist
  # Tokens are added when users sign out or when tokens are revoked
  # After expiration, they no longer need to be in the denylist
  #
  # Schedule with sidekiq-cron or call from a cron job:
  #   JwtCleanupJob.perform_later
  #
  def perform
    now = Time.current

    expired_count = batch_delete(JwtDenylist.where("exp < ?", now))
    expired_refresh_count = batch_delete(RefreshToken.where("expires_at <= ?", now))

    stale_revoked_count = batch_delete(
      RefreshToken.revoked
                  .where("revoked_at < ?", ACTIVE_FAMILY_REVOKED_RETENTION_DAYS.days.ago)
                  .where(family: active_families(now))
    )

    prunable_families = inactive_families_to_prune(now)
    inactive_families_pruned = grouped_family_count(prunable_families)
    inactive_family_tokens_removed = batch_delete(RefreshToken.where(family: prunable_families))

    total_cleaned = expired_count + expired_refresh_count + stale_revoked_count + inactive_family_tokens_removed
    remaining_tokens = JwtDenylist.count
    remaining_refresh_tokens = RefreshToken.count

    Rails.logger.info(
      event: "jwt_cleanup_completed",
      expired_tokens_removed: expired_count,
      expired_refresh_tokens_removed: expired_refresh_count,
      stale_revoked_refresh_tokens_removed: stale_revoked_count,
      inactive_families_pruned: inactive_families_pruned,
      inactive_family_tokens_removed: inactive_family_tokens_removed,
      remaining_tokens: remaining_tokens,
      remaining_refresh_tokens: remaining_refresh_tokens
    )

    track_metrics(
      remaining_tokens: remaining_tokens,
      remaining_refresh_tokens: remaining_refresh_tokens,
      inactive_families_pruned: inactive_families_pruned
    )

    total_cleaned
  end

  private

  def batch_delete(scope)
    deleted_count = 0
    scope.in_batches(of: delete_batch_size) do |batch|
      deleted_count += batch.delete_all
    end
    deleted_count
  end

  def delete_batch_size
    @delete_batch_size ||= [ DELETE_BATCH_SIZE, 1 ].max
  end

  def active_families(now)
    RefreshToken.where(revoked_at: nil).where("expires_at > ?", now).select(:family)
  end

  def inactive_families_to_prune(now)
    cutoff = INACTIVE_FAMILY_RETENTION_DAYS.days.ago
    RefreshToken.where.not(family: active_families(now))
                .group(:family)
                .having("MAX(COALESCE(revoked_at, expires_at, created_at)) < ?", cutoff)
                .select(:family)
  end

  def grouped_family_count(scope)
    result = scope.count
    result.is_a?(Hash) ? result.size : result
  end

  def track_metrics(remaining_tokens:, remaining_refresh_tokens:, inactive_families_pruned:)
    return unless defined?(ApplicationMonitor)

    ApplicationMonitor.track_metric("auth.jwt_denylist.remaining", remaining_tokens)
    ApplicationMonitor.track_metric("auth.refresh_tokens.remaining", remaining_refresh_tokens)
    ApplicationMonitor.track_metric("auth.refresh_inactive_families_pruned", inactive_families_pruned)
  rescue StandardError => e
    Rails.logger.error(
      event: "jwt_cleanup_metric_tracking_failed",
      error_class: e.class.name,
      error_message: e.message
    )
  end
end
