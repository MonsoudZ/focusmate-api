# frozen_string_literal: true

class AlertingCheckJob < ApplicationJob
  queue_as :critical

  # Run every 5 minutes to check alerting thresholds
  # This provides near-real-time alerting for critical issues
  #
  # Schedule with sidekiq-cron:
  #   AlertingCheckJob.perform_later
  #
  def perform
    results = AlertingService.check_all_thresholds

    triggered_alerts = results.select { |_, v| v[:triggered] && !v[:in_cooldown] }

    Rails.logger.info(
      event: "alerting_check_completed",
      total_checks: results.count,
      triggered_count: triggered_alerts.count,
      results: results
    )

    results
  end
end