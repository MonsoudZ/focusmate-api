# frozen_string_literal: true

class Rack::Attack
  # Configure cache store
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  )

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Extract authenticated user ID from the JWT in the Authorization header.
  # Returns nil for unauthenticated requests (they fall through to IP throttles).
  def self.authenticated_user_id(req)
    token = req.get_header("HTTP_AUTHORIZATION").to_s.remove("Bearer ")
    return nil if token.blank?

    payload = JWT.decode(
      token,
      Rails.application.credentials.secret_key_base || Rails.application.secret_key_base,
      true,
      { algorithm: "HS256" }
    ).first

    payload["sub"]
  rescue JWT::DecodeError
    nil
  end

  # ---------------------------------------------------------------------------
  # Safelists
  # ---------------------------------------------------------------------------

  Rack::Attack.safelist("allow-localhost") do |req|
    ("127.0.0.1" == req.ip || "::1" == req.ip) if Rails.env.development?
  end

  # ---------------------------------------------------------------------------
  # IP-based throttles (unauthenticated / fallback)
  # ---------------------------------------------------------------------------

  # General API — 100 req/min per IP
  Rack::Attack.throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Authentication endpoints — 5 req/min per IP
  AUTH_PATHS = %w[
    /api/v1/login
    /api/v1/register
    /api/v1/auth/sign_in
    /api/v1/auth/sign_up
    /api/v1/auth/apple
  ].freeze

  Rack::Attack.throttle("auth/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.post? && AUTH_PATHS.include?(req.path)
  end

  # Password reset — 3 req/hour per IP
  Rack::Attack.throttle("password_reset/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/users/password")
  end

  # Token refresh — 10 req/min per IP
  Rack::Attack.throttle("refresh/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/api/v1/auth/refresh"
  end

  # ---------------------------------------------------------------------------
  # Per-user throttles (authenticated requests)
  # ---------------------------------------------------------------------------

  # General API — 300 req/min per user (higher than IP limit since a user
  # behind NAT shouldn't be penalised for other users on the same IP)
  Rack::Attack.throttle("api/user",
    limit: ENV.fetch("RATE_LIMIT_API_PER_USER", 300).to_i,
    period: 1.minute
  ) do |req|
    next unless req.path.start_with?("/api/")
    authenticated_user_id(req)
  end

  # Write operations — 60 req/min per user
  Rack::Attack.throttle("api/user/writes",
    limit: ENV.fetch("RATE_LIMIT_WRITES_PER_USER", 60).to_i,
    period: 1.minute
  ) do |req|
    next unless req.path.start_with?("/api/")
    next if req.get? || req.head? || req.options?
    authenticated_user_id(req)
  end

  # ---------------------------------------------------------------------------
  # Custom 429 response
  # ---------------------------------------------------------------------------

  Rack::Attack.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_s

    headers = {
      "Content-Type" => "application/json",
      "Retry-After" => retry_after
    }

    error_response = {
      error: {
        message: "Rate limit exceeded. Try again in #{retry_after} seconds.",
        status: 429,
        retry_after: retry_after.to_i,
        timestamp: Time.current.iso8601
      }
    }
    [ 429, headers, [ error_response.to_json ] ]
  end
end
