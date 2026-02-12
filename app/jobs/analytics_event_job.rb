# frozen_string_literal: true

class AnalyticsEventJob < ApplicationJob
  include RateLimitedSentryReporting

  queue_as :default
  SENTRY_ERROR_TTL = 5.minutes

  # Low priority - analytics should not block other jobs
  # Discard if the record was deleted before job runs
  discard_on ActiveJob::DeserializationError

  def perform(user_id:, event_type:, metadata: {}, task_id: nil, list_id: nil, occurred_at: nil)
    AnalyticsEvent.create!(
      user_id: user_id,
      task_id: task_id,
      list_id: list_id,
      event_type: event_type,
      metadata: metadata,
      occurred_at: occurred_at || Time.current
    )
  rescue StandardError => e
    Rails.logger.error("AnalyticsEventJob failed: #{e.message}")
    digest = Digest::SHA256.hexdigest(e.message.to_s)[0, 16]
    report_error_once(
      e,
      cache_key: "analytics_event_job:error:#{e.class.name}:#{digest}",
      ttl: SENTRY_ERROR_TTL,
      extra: { user_id: user_id, event_type: event_type, task_id: task_id, list_id: list_id }
    )
    # Don't re-raise - analytics failures should not retry endlessly
  end
end
