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

    Rails.logger.info(
      event: "jwt_cleanup_completed",
      expired_tokens_removed: expired_count,
      remaining_tokens: JwtDenylist.count
    )

    # Track in Sentry for observability
    Sentry.capture_message(
      "JWT cleanup completed",
      level: :info,
      extra: {
        expired_tokens_removed: expired_count,
        remaining_tokens: JwtDenylist.count
      }
    ) if expired_count > 1000 # Only alert if significant cleanup

    expired_count
  end
end