# frozen_string_literal: true

module Middleware
  class SecurityHeaders
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      # Prevent MIME type sniffing
      headers["X-Content-Type-Options"] = "nosniff"

      # Deny framing (API should never be embedded)
      headers["X-Frame-Options"] = "DENY"

      # Disable XSS auditor (outdated; CSP is the replacement)
      headers["X-XSS-Protection"] = "0"

      # Control referrer leakage
      headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

      # Restrict browser features — API needs none
      headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=()"

      # CSP for an API: serve nothing, allow nothing
      headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'"

      # Prevent caching of API responses (credentials, user data)
      headers["Cache-Control"] = "no-store" unless headers["Cache-Control"]

      [ status, headers, response ]
    end
  end
end
