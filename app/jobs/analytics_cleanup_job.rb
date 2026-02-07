# frozen_string_literal: true

class AnalyticsCleanupJob < ApplicationJob
  queue_as :maintenance

  # Retention period for analytics events (default: 90 days)
  RETENTION_DAYS = ENV.fetch("ANALYTICS_RETENTION_DAYS", 90).to_i

  # Run weekly to archive/delete old analytics events
  # This prevents the analytics_events table from growing unbounded
  #
  # Schedule with sidekiq-cron or call from a cron job:
  #   AnalyticsCleanupJob.perform_later
  #
  def perform
    cutoff_date = RETENTION_DAYS.days.ago

    deleted_count = 0
    AnalyticsEvent
      .where("occurred_at < ?", cutoff_date)
      .in_batches(of: 10_000) do |batch|
        deleted_count += batch.delete_all
      end

    Rails.logger.info(
      event: "analytics_cleanup_completed",
      retention_days: RETENTION_DAYS,
      cutoff_date: cutoff_date.iso8601,
      events_deleted: deleted_count
    )

    # Alert if we're deleting a lot - might indicate a problem
    if deleted_count > 100_000
      report_large_cleanup(deleted_count)
    end

    deleted_count
  end

  private

  def report_large_cleanup(deleted_count)
    return unless defined?(Sentry)

    Sentry.capture_message(
      "Large analytics cleanup",
      level: :warning,
      extra: {
        events_deleted: deleted_count,
        retention_days: RETENTION_DAYS
      }
    )
  rescue StandardError => e
    Rails.logger.error("AnalyticsCleanupJob Sentry report failed: #{e.message}")
  end
end
