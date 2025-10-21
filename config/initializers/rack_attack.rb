# frozen_string_literal: true

class Rack::Attack
  # Configure cache store
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  )

  # Allow requests from localhost in development
  Rack::Attack.safelist("allow-localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip if Rails.env.development?
  end

  # Rate limiting for API endpoints
  Rack::Attack.throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Rate limiting for authentication endpoints
  Rack::Attack.throttle("auth/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/users/sign_in") || req.path.start_with?("/users/sign_up")
  end

  # Rate limiting for password reset
  Rack::Attack.throttle("password_reset/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/users/password")
  end

  # Block suspicious requests
  Rack::Attack.blocklist("block bad user agents") do |req|
    req.user_agent =~ /(bot|crawler|spider|scraper)/i
  end

  # Custom response for blocked requests
  Rack::Attack.throttled_responder = lambda do |env|
    headers = { "Content-Type" => "application/json" }
    error_response = {
      error: {
        message: "Rate limit exceeded",
        status: 429,
        timestamp: Time.current.iso8601
      }
    }
    [ 429, headers, [ error_response.to_json ] ]
  end
end
