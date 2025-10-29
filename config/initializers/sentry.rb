# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", nil)
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.environment = Rails.env
  config.traces_sample_rate = 0.3  # tune up/down later
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
