# frozen_string_literal: true

module RateLimitedSentryReporting
  private

  def report_error_once(error, cache_key:, ttl:, extra: {})
    return unless defined?(Sentry)
    return if recently_reported?(cache_key)

    mark_reported(cache_key, ttl)
    Sentry.capture_exception(error, extra: extra)
  rescue StandardError => sentry_error
    Rails.logger.error(
      event: "sentry_report_failed",
      reporter: self.class.name,
      error_class: sentry_error.class.name,
      error_message: sentry_error.message
    )
  end

  def recently_reported?(cache_key)
    Rails.cache.read(cache_key).present?
  end

  def mark_reported(cache_key, ttl)
    Rails.cache.write(cache_key, true, expires_in: ttl)
  end
end
