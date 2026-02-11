# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn) || ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.environment = Rails.env
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.05).to_f
  config.send_default_pii = false

  # Filter sensitive parameters
  config.before_send = lambda do |event, hint|
    # Remove sensitive data from request parameters
    if event.request&.data
      event.request.data = event.request.data.except("password", "password_confirmation", "token", "secret")
    end

    # Remove sensitive headers
    if event.request&.headers
      event.request.headers = event.request.headers.except("Authorization", "X-API-Key")
    end

    event
  end
end
