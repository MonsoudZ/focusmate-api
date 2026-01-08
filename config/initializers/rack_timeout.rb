# frozen_string_literal: true

# Rack::Timeout configuration
# ===========================
# Prevents slow requests from blocking Puma workers indefinitely.
# Workers will be terminated if requests exceed the timeout.
#
# To enable, add to Gemfile:
#   gem "rack-timeout"
#

if defined?(Rack::Timeout)
  # Configure via environment variables (rack-timeout reads these automatically)
  # RACK_TIMEOUT_SERVICE_TIMEOUT - how long a request can run (default: 15s)
  # RACK_TIMEOUT_WAIT_TIMEOUT - how long request can wait in queue (default: 30s)
  # RACK_TIMEOUT_WAIT_OVERTIME - extra time if wait_timeout exceeded (default: 60s)

  # Set defaults if not already set in environment
  ENV["RACK_TIMEOUT_SERVICE_TIMEOUT"] ||= "15"
  ENV["RACK_TIMEOUT_WAIT_TIMEOUT"] ||= "30"
  ENV["RACK_TIMEOUT_WAIT_OVERTIME"] ||= "60"

  # Reduce log noise - rack-timeout logs are verbose by default
  if defined?(Rack::Timeout::Logger)
    Rack::Timeout::Logger.level = Logger::WARN
  end

  Rails.logger.info("Rack::Timeout configured: service=#{ENV['RACK_TIMEOUT_SERVICE_TIMEOUT']}s, wait=#{ENV['RACK_TIMEOUT_WAIT_TIMEOUT']}s")
end
