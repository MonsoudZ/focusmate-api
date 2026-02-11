# frozen_string_literal: true

Devise.setup do |config|
  # The secret key used by Devise.
  # Devise uses this key to generate random tokens.
  # If you change this key, all old tokens will become invalid.
  config.secret_key = Rails.application.secret_key_base

  # ==> Mailer Configuration
  # Configure the e-mail address which will be shown in Devise::Mailer.
  config.mailer_sender = ENV.fetch("DEVISE_MAILER_SENDER", "noreply@focusmate.app")

  # ==> ORM configuration
  require "devise/orm/active_record"

  # ==> Configuration for any authentication mechanism
  # Configure which keys are used when authenticating a user.
  config.authentication_keys = [ :email ]

  # Configure parameters permitted by Devise.
  # If you use custom Devise controllers, you may need to permit additional parameters there.
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  # Skip session storage for API-only / JWT auth.
  # This ensures Devise never attempts to write session data.
  config.skip_session_storage = [ :http_auth, :database, :params_auth ]

  # ==> Navigation
  # For API-only apps, do not use navigational formats (no redirects / HTML responses).
  config.navigational_formats = []

  # ==> Password settings
  config.stretches = Rails.env.test? ? 1 : 12
  pepper = Rails.application.credentials.dig(:devise, :pepper) || ENV["DEVISE_PEPPER"]
  config.pepper = pepper if pepper.present?

  # ==> JWT configuration (Devise-JWT)
  config.jwt do |jwt|
    jwt.secret = Rails.application.secret_key_base

    # Issue tokens on sign-in and sign-up
    jwt.dispatch_requests = [
      [ "POST", %r{^/api/v1/auth/sign_in$} ],
      [ "POST", %r{^/api/v1/auth/sign_up$} ]
    ]

    # Revoke tokens on sign-out
    jwt.revocation_requests = [
      [ "DELETE", %r{^/api/v1/auth/sign_out$} ]
    ]

    # Access token lifetime — short-lived for security (1 hour default)
    # Use refresh tokens for long-lived sessions (30 days)
    # Configurable via env var for gradual rollout
    jwt.expiration_time = ENV.fetch("JWT_ACCESS_TOKEN_LIFETIME_SECONDS", 1.hour.to_i).to_i
  end

  # ==> Warden configuration
  config.warden do |manager|
    # Use a custom failure app to return JSON for authentication failures.
    manager.failure_app = ApiFailureApp

    # If false, Devise won't intercept 401 responses; failure_app should handle them.
    manager.intercept_401 = false
  end
end
