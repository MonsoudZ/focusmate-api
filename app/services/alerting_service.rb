# frozen_string_literal: true

# AlertingService provides threshold-based alerting for application metrics.
# It integrates with Sentry and can be extended to support other channels
# like Slack, PagerDuty, email, etc.
#
# Usage:
#   AlertingService.check_all_thresholds
#   AlertingService.check(:high_error_rate, current_value: 0.15)
#
class AlertingService
  SENTRY_FAILURE_TTL = ApplicationMonitor::SENTRY_FAILURE_TTL

  # Define alert thresholds and conditions
  ALERTS = {
    high_error_rate: {
      description: "Error rate exceeds threshold",
      threshold: 0.05, # 5%
      comparison: :greater_than,
      severity: :error,
      cooldown_minutes: 15
    },
    high_response_time: {
      description: "Average response time too high",
      threshold: 2000, # 2 seconds in ms
      comparison: :greater_than,
      severity: :warning,
      cooldown_minutes: 10
    },
    queue_backlog: {
      description: "Queue backlog too large",
      threshold: 1000,
      comparison: :greater_than,
      severity: :warning,
      cooldown_minutes: 5
    },
    dead_jobs: {
      description: "Dead jobs accumulating",
      threshold: 10,
      comparison: :greater_than,
      severity: :error,
      cooldown_minutes: 30
    },
    memory_usage: {
      description: "Memory usage high",
      threshold: 512, # MB
      comparison: :greater_than,
      severity: :warning,
      cooldown_minutes: 30
    },
    database_connections: {
      description: "Database connection pool exhaustion",
      threshold: 0.9, # 90% usage
      comparison: :greater_than,
      severity: :error,
      cooldown_minutes: 5
    }
  }.freeze

  class << self
    # Check all defined thresholds
    def check_all_thresholds
      results = {}

      results[:queue_backlog] = check(:queue_backlog, current_value: queue_pending)
      results[:dead_jobs] = check(:dead_jobs, current_value: queue_failed)
      results[:database_connections] = check(:database_connections, current_value: db_connection_ratio)
      results[:memory_usage] = check(:memory_usage, current_value: memory_mb)

      results
    end

    # Check a single threshold
    def check(alert_name, current_value:)
      alert_config = ALERTS[alert_name]
      return { error: "Unknown alert: #{alert_name}" } unless alert_config

      cooldown_before_check = in_cooldown?(alert_name)
      triggered = threshold_exceeded?(
        current_value,
        alert_config[:threshold],
        alert_config[:comparison]
      )

      if triggered && !cooldown_before_check
        fire_alert(alert_name, alert_config, current_value)
        record_alert_fired(alert_name)
      end

      {
        alert: alert_name,
        triggered: triggered,
        current_value: current_value,
        threshold: alert_config[:threshold],
        in_cooldown: cooldown_before_check
      }
    end

    private

    def threshold_exceeded?(current, threshold, comparison)
      case comparison
      when :greater_than then current > threshold
      when :less_than then current < threshold
      when :equals then current == threshold
      else false
      end
    end

    def in_cooldown?(alert_name)
      cooldown_key = "alert_cooldown:#{alert_name}"
      Rails.cache.exist?(cooldown_key)
    end

    def record_alert_fired(alert_name)
      config = ALERTS[alert_name]
      cooldown_key = "alert_cooldown:#{alert_name}"
      Rails.cache.write(cooldown_key, true, expires_in: config[:cooldown_minutes].minutes)
    end

    def fire_alert(alert_name, config, current_value)
      message = "#{config[:description]}: #{current_value} (threshold: #{config[:threshold]})"

      Rails.logger.error(
        event: "alert_fired",
        alert: alert_name,
        description: config[:description],
        current_value: current_value,
        threshold: config[:threshold],
        severity: config[:severity]
      )

      # Send to Sentry
      if defined?(Sentry)
        capture_sentry_message(
          "Alert: #{config[:description]}",
          level: config[:severity] == :error ? :error : :warning,
          extra: {
            alert_name: alert_name,
            current_value: current_value,
            threshold: config[:threshold]
          },
          tags: {
            alert_type: alert_name.to_s,
            severity: config[:severity].to_s
          }
        )
      end

      # Add Slack/PagerDuty integration here if needed
      # SlackNotifier.alert(message) if config[:severity] == :error
    end

    # Metric collection methods
    def queue_pending
      SolidQueue::ReadyExecution.count
    rescue StandardError => e
      log_metric_collection_error_once(e, metric: "queue_pending")
      0
    end

    def queue_failed
      SolidQueue::FailedExecution.count
    rescue StandardError => e
      log_metric_collection_error_once(e, metric: "queue_failed")
      0
    end

    def db_connection_ratio
      pool = ActiveRecord::Base.connection_pool
      pool.connections.size.to_f / pool.size
    rescue StandardError => e
      log_metric_collection_error_once(e, metric: "db_connection_ratio")
      0
    end

    def memory_mb
      return 0 unless defined?(GetProcessMem)
      GetProcessMem.new.mb
    rescue StandardError => e
      log_metric_collection_error_once(e, metric: "memory_mb")
      0
    end

    def capture_sentry_message(*args, **kwargs)
      Sentry.capture_message(*args, **kwargs)
    rescue StandardError => e
      digest = Digest::SHA256.hexdigest(e.message.to_s)[0, 16]
      cache_key = "alerting_service:sentry_failure:#{e.class.name}:#{digest}"
      return if Rails.cache.read(cache_key).present?

      Rails.cache.write(cache_key, true, expires_in: SENTRY_FAILURE_TTL)
      Rails.logger.error(
        event: "alerting_service_sentry_failure",
        error_class: e.class.name,
        error_message: e.message
      )
    end

    def log_metric_collection_error_once(error, metric:)
      digest = Digest::SHA256.hexdigest(error.message.to_s)[0, 16]
      cache_key = "alerting_service:metric_failure:#{metric}:#{error.class.name}:#{digest}"
      return if Rails.cache.read(cache_key).present?

      Rails.cache.write(cache_key, true, expires_in: SENTRY_FAILURE_TTL)
      Rails.logger.error(
        event: "alerting_metric_collection_failed",
        metric: metric,
        error_class: error.class.name,
        error_message: error.message
      )
    end
  end
end
