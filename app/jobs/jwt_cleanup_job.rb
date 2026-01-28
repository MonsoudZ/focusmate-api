# frozen_string_literal: true

class JwtCleanupJob < ApplicationJob
  queue_as :maintenance

  # Run daily to clean up expired JWT tokens from the denylist
  # Tokens are added when users sign out or when tokens are revoked
  # After expiration, they no longer need to be in the denylist
  #
  # Schedule with sidekiq-cron or call from a cron job:
  #   JwtCleanupJob.perform_later
  #
  def perform
    expired_count = JwtDenylist.where("exp < ?", Time.current).delete_all

    # Clean up expired refresh tokens
    expired_refresh_count = RefreshToken.expired.delete_all

    # Clean up revoked refresh tokens older than 7 days (keep recent ones for audit)
    stale_revoked_count = RefreshToken.revoked.where("revoked_at < ?", 7.days.ago).delete_all

    total_cleaned = expired_count + expired_refresh_count + stale_revoked_count

    Rails.logger.info(
      event: "jwt_cleanup_completed",
      expired_tokens_removed: expired_count,
      expired_refresh_tokens_removed: expired_refresh_count,
      stale_revoked_refresh_tokens_removed: stale_revoked_count,
      remaining_tokens: JwtDenylist.count,
      remaining_refresh_tokens: RefreshToken.count
    )

    # Track in Sentry for observability
    Sentry.capture_message(
      "JWT cleanup completed",
      level: :info,
      extra: {
        expired_tokens_removed: expired_count,
        expired_refresh_tokens_removed: expired_refresh_count,
        stale_revoked_refresh_tokens_removed: stale_revoked_count,
        remaining_tokens: JwtDenylist.count,
        remaining_refresh_tokens: RefreshToken.count
      }
    ) if total_cleaned > 1000 # Only alert if significant cleanup

    total_cleaned
  end
end
