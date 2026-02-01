# frozen_string_literal: true

# CORS (Cross-Origin Resource Sharing) configuration
#
# This configures which origins can make requests to the API.
# For mobile apps (iOS/Android), CORS is typically not needed since
# native apps don't have the same-origin policy. However, this is
# useful for:
# - Web-based admin dashboards
# - Development/testing from browser tools
# - Future web clients
#
# Configuration via environment variables:
#   CORS_ORIGINS - Comma-separated list of allowed origins
#                  Example: "https://app.focusmate.com,https://admin.focusmate.com"
#                  Default: Allows localhost in development, none in production
#
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Parse origins from environment variable or use defaults
    origins_config = ENV.fetch("CORS_ORIGINS", nil)

    if origins_config.present?
      # Production: Use explicit origins from env var
      origins(*origins_config.split(",").map(&:strip))
    elsif Rails.env.development? || Rails.env.test?
      # Development/Test: Allow localhost on common ports
      origins(
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:8080",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
        "http://127.0.0.1:8080",
        %r{\Ahttp://localhost:\d+\z},
        %r{\Ahttp://127\.0\.0\.1:\d+\z}
      )
    else
      # Production without CORS_ORIGINS: No origins allowed
      # This effectively disables CORS (API is mobile-only)
      origins []
    end

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization", "X-Request-Id" ],
      max_age: 86_400, # Cache preflight for 24 hours
      credentials: false # Set to true if you need cookies/auth headers from browser
  end
end
