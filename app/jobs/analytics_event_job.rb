# frozen_string_literal: true

class AnalyticsEventJob < ApplicationJob
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
    report_error_once(
      e,
      user_id: user_id,
      event_type: event_type,
      task_id: task_id,
      list_id: list_id
    )
    # Don't re-raise - analytics failures should not retry endlessly
  end

  private

  def report_error_once(error, **context)
    return unless defined?(Sentry)
    return if recently_reported?(error)

    mark_reported(error)
    Sentry.capture_exception(error, extra: context)
  rescue StandardError => sentry_error
    Rails.logger.error("AnalyticsEventJob Sentry report failed: #{sentry_error.message}")
  end

  def recently_reported?(error)
    Rails.cache.read(sentry_cache_key(error)).present?
  end

  def mark_reported(error)
    Rails.cache.write(sentry_cache_key(error), true, expires_in: SENTRY_ERROR_TTL)
  end

  def sentry_cache_key(error)
    "analytics_event_job:error:#{error.class.name}:#{error.message}"
  end
end
