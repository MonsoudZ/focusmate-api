# frozen_string_literal: true

# ApplicationMonitor provides a centralized interface for tracking
# custom application metrics and events. It wraps Sentry and logs
# to provide consistent observability.
#
# Usage:
#   ApplicationMonitor.track_event("user_signed_up", user_id: user.id)
#   ApplicationMonitor.track_metric("api_latency", 150, tags: { endpoint: "/tasks" })
#   ApplicationMonitor.alert("High error rate detected", severity: :warning)
#
class ApplicationMonitor
  class << self
    # Track a business event
    def track_event(event_name, **metadata)
      log_event(event_name, metadata)
      send_to_sentry(event_name, metadata, level: :info)
    end

    # Track a numeric metric
    def track_metric(metric_name, value, tags: {})
      Rails.logger.info(
        event: "metric",
        metric: metric_name,
        value: value,
        tags: tags,
        timestamp: Time.current.iso8601
      )

      # If you add StatsD/Datadog later:
      # StatsD.gauge(metric_name, value, tags: tags)
    end

    # Track timing of a block
    def track_timing(operation_name, tags: {})
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

      track_metric("#{operation_name}.duration_ms", duration_ms, tags: tags)

      # Alert on slow operations
      if duration_ms > 5000 # 5 seconds
        alert("Slow operation: #{operation_name}",
              severity: :warning,
              duration_ms: duration_ms,
              tags: tags)
      end

      result
    end

    # Send an alert (shows up prominently in Sentry)
    def alert(message, severity: :warning, **context)
      level = case severity
              when :critical, :error then :error
              when :warning then :warning
              else :info
              end

      Rails.logger.send(level == :info ? :info : :warn,
                        event: "alert",
                        message: message,
                        severity: severity,
                        context: context
      )

      send_to_sentry("Alert: #{message}", context, level: level)
    end

    # Track an error with context (without raising)
    def track_error(error, **context)
      Rails.logger.error(
        event: "error_tracked",
        error_class: error.class.name,
        error_message: error.message,
        context: context
      )

      Sentry.capture_exception(error, extra: context) if defined?(Sentry)
    end

    # Health metrics for dashboards
    def health_snapshot
      {
        timestamp: Time.current.iso8601,
        database: database_health,
        redis: redis_health,
        sidekiq: sidekiq_health,
        memory: memory_usage
      }
    end

    private

    def log_event(event_name, metadata)
      Rails.logger.info(
        event: event_name,
        **metadata,
        timestamp: Time.current.iso8601
      )
    end

    def send_to_sentry(message, context, level:)
      return unless defined?(Sentry)

      Sentry.capture_message(message, level: level, extra: context)
    rescue StandardError => e
      Rails.logger.error("Failed to send to Sentry: #{e.message}")
    end

    def database_health
      {
        connected: ActiveRecord::Base.connected?,
        pool_size: ActiveRecord::Base.connection_pool.size,
        pool_usage: ActiveRecord::Base.connection_pool.connections.size
      }
    rescue StandardError => e
      { error: e.message }
    end

    def redis_health
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
      info = redis.info
      {
        connected: true,
        version: info["redis_version"],
        memory_used: info["used_memory_human"],
        connected_clients: info["connected_clients"]
      }
    rescue StandardError => e
      { connected: false, error: e.message }
    end

    def sidekiq_health
      stats = Sidekiq::Stats.new
      {
        processed: stats.processed,
        failed: stats.failed,
        queues: stats.queues,
        enqueued: stats.enqueued,
        retry_size: stats.retry_size,
        dead_size: stats.dead_size
      }
    rescue StandardError => e
      { error: e.message }
    end

    def memory_usage
      if defined?(GetProcessMem)
        mem = GetProcessMem.new
        { rss_mb: mem.mb.round(2) }
      else
        {}
      end
    rescue StandardError
      {}
    end
  end
end