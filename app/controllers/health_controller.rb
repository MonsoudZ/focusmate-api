# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :force_json_format

  # Liveness probe - basic application health
  def live
    head :ok
  end

  # Readiness probe - comprehensive service health
  def ready
    start_time = Time.current
    checks = perform_health_checks
    duration = ((Time.current - start_time) * 1000).round(2)

    overall_status = checks.values.all? { |check| check[:status] == "healthy" } ? "healthy" : "degraded"

    response_data = {
      status: overall_status,
      timestamp: Time.current.iso8601,
      duration_ms: duration,
      version: application_version,
      environment: Rails.env,
      checks: checks
    }

    status_code = overall_status == "healthy" ? :ok : :service_unavailable
    render json: response_data, status: status_code
  end

  # Detailed health check with more information
  def detailed
    start_time = Time.current
    checks = perform_detailed_health_checks
    duration = ((Time.current - start_time) * 1000).round(2)

    overall_status = checks.values.all? { |check| check[:status] == "healthy" } ? "healthy" : "degraded"

    response_data = {
      status: overall_status,
      timestamp: Time.current.iso8601,
      duration_ms: duration,
      version: application_version,
      environment: Rails.env,
      uptime: application_uptime,
      memory_usage: memory_usage,
      checks: checks
    }

    status_code = overall_status == "healthy" ? :ok : :service_unavailable
    render json: response_data, status: status_code
  end

  # Metrics endpoint for monitoring systems
  def metrics
    checks = perform_health_checks

    # Return in a format suitable for monitoring systems
    metrics_data = {
      health_status: checks.values.all? { |check| check[:status] == "healthy" } ? 1 : 0,
      database_status: checks[:database][:status] == "healthy" ? 1 : 0,
      redis_status: checks[:redis][:status] == "healthy" ? 1 : 0,
      queue_status: checks[:queue][:status] == "healthy" ? 1 : 0,
      timestamp: Time.current.to_i
    }

    render json: metrics_data, status: :ok
  end

  private

  def perform_health_checks
    {
      database: database_health_check,
      redis: redis_health_check,
      queue: queue_health_check
    }
  end

  def perform_detailed_health_checks
    {
      database: database_health_check,
      redis: redis_health_check,
      queue: queue_health_check,
      storage: storage_health_check,
      external_apis: external_apis_health_check
    }
  end

  def database_health_check
    start_time = Time.current
    connection = ActiveRecord::Base.connection
    connection.active?

    # Test a simple query
    connection.execute("SELECT 1")

    duration = ((Time.current - start_time) * 1000).round(2)

    {
      status: "healthy",
      response_time_ms: duration,
      message: "Database connection active and responsive"
    }
  rescue => e
    Rails.logger.error "Database health check failed: #{e.message}"
    {
      status: "unhealthy",
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      message: e.message,
      error: e.class.name
    }
  end

  def redis_health_check
    start_time = Time.current

    # Use the configured Redis instance
    redis = if defined?(Redis.current)
              Redis.current
    elsif defined?(Sidekiq) && Sidekiq.respond_to?(:redis)
              Sidekiq.redis { |conn| conn }
    else
              Redis.new
    end

    response = redis.ping

    duration = ((Time.current - start_time) * 1000).round(2)

    if response == "PONG"
      {
        status: "healthy",
        response_time_ms: duration,
        message: "Redis connection active and responsive"
      }
    else
      {
        status: "unhealthy",
        response_time_ms: duration,
        message: "Unexpected Redis response: #{response}"
      }
    end
  rescue => e
    Rails.logger.error "Redis health check failed: #{e.message}"
    {
      status: "unhealthy",
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      message: e.message,
      error: e.class.name
    }
  end

  def queue_health_check
    start_time = Time.current

    # Check if Sidekiq is available and responsive
    if defined?(Sidekiq)
      # Try to get Redis info through Sidekiq
      redis_info = if Sidekiq.respond_to?(:redis_info)
                     Sidekiq.redis_info
      elsif Sidekiq.respond_to?(:redis)
                     Sidekiq.redis { |conn| conn.info }
      else
                     nil
      end

      queue_size = Sidekiq::Queue.new.size rescue 0
      failed_jobs = Sidekiq::DeadSet.new.size rescue 0

      duration = ((Time.current - start_time) * 1000).round(2)

      {
        status: "healthy",
        response_time_ms: duration,
        message: "Queue system operational",
        details: {
          queue_size: queue_size,
          failed_jobs: failed_jobs,
          redis_connected: redis_info.present?
        }
      }
    else
      {
        status: "unhealthy",
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: "Sidekiq not available"
      }
    end
  rescue => e
    Rails.logger.error "Queue health check failed: #{e.message}"
    {
      status: "unhealthy",
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      message: e.message,
      error: e.class.name
    }
  end

  def storage_health_check
    start_time = Time.current

    # Check if file storage is working
    if Rails.application.config.active_storage.service == :local
      storage_path = Rails.root.join("storage")
      if Dir.exist?(storage_path) && File.writable?(storage_path)
        {
          status: "healthy",
          response_time_ms: ((Time.current - start_time) * 1000).round(2),
          message: "Local storage accessible and writable"
        }
      else
        {
          status: "unhealthy",
          response_time_ms: ((Time.current - start_time) * 1000).round(2),
          message: "Local storage not accessible or not writable"
        }
      end
    else
      # For cloud storage, we could add specific checks here
      {
        status: "healthy",
        response_time_ms: ((Time.current - start_time) * 1000).round(2),
        message: "Cloud storage configured (not tested)"
      }
    end
  rescue => e
    Rails.logger.error "Storage health check failed: #{e.message}"
    {
      status: "unhealthy",
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      message: e.message,
      error: e.class.name
    }
  end

  def external_apis_health_check
    start_time = Time.current

    # Check external API dependencies
    checks = {}

    # Add checks for external APIs your application depends on
    # Example: APNS, FCM, etc.

    duration = ((Time.current - start_time) * 1000).round(2)

    if checks.empty?
      {
        status: "healthy",
        response_time_ms: duration,
        message: "No external API dependencies configured"
      }
    else
      all_healthy = checks.values.all? { |check| check[:status] == "healthy" }
      {
        status: all_healthy ? "healthy" : "degraded",
        response_time_ms: duration,
        message: all_healthy ? "All external APIs operational" : "Some external APIs unavailable",
        details: checks
      }
    end
  rescue => e
    Rails.logger.error "External APIs health check failed: #{e.message}"
    {
      status: "unhealthy",
      response_time_ms: ((Time.current - start_time) * 1000).round(2),
      message: e.message,
      error: e.class.name
    }
  end

  def application_uptime
    # Calculate application uptime
    if defined?(Rails::Server) && Rails.server
      Time.current - Rails.application.config.boot_time
    else
      "unknown"
    end
  rescue
    "unknown"
  end

  def memory_usage
    # Get memory usage information
    if defined?(RSS)
      rss = RSS::Memory.new
      {
        rss_mb: (rss.rss / 1024.0 / 1024.0).round(2),
        pss_mb: (rss.pss / 1024.0 / 1024.0).round(2)
      }
    else
      { message: "Memory usage not available" }
    end
  rescue
    { message: "Memory usage not available" }
  end

  def application_version
    # Try to get version from various sources
    if defined?(VERSION)
      VERSION
    elsif File.exist?(Rails.root.join("VERSION"))
      File.read(Rails.root.join("VERSION")).strip
    elsif defined?(Rails.application.config.version)
      Rails.application.config.version
    else
      "unknown"
    end
  rescue
    "unknown"
  end
end
