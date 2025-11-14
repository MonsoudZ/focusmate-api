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

  # Rate limiting for authentication endpoints (API routes and iOS aliases)
  Rack::Attack.throttle("auth/ip", limit: 5, period: 1.minute) do |req|
    next unless req.post?
    path = req.path
    req.ip if [
      "/api/v1/login",
      "/api/v1/register",
      "/api/v1/auth/sign_in",
      "/api/v1/auth/sign_up"
    ].any? { |p| path == p }
  end

  # Rate limiting for password reset
  Rack::Attack.throttle("password_reset/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path.start_with?("/users/password")
  end

  # Safelist legitimate bots (Google, Bing, monitoring tools, etc.)
  Rack::Attack.safelist("allow good bots") do |req|
    req.user_agent =~ /(googlebot|bingbot|yandexbot|duckduckbot|slackbot|twitterbot|facebookexternalhit|linkedinbot|whatsapp|discordbot|telegrambot|uptimerobot|pingdom|newrelic)/i
  end

  # Block known malicious user agents
  Rack::Attack.blocklist("block bad user agents") do |req|
    # Block empty user agents and known malicious patterns
    # But don't block legitimate bots (they're safelisted above)
    req.user_agent.blank? ||
    req.user_agent =~ /(masscan|nmap|nikto|sqlmap|acunetix|nessus|openvas|metasploit|havij|libwww-perl)/i
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
