# frozen_string_literal: true

class DatabaseHealthCheckJob < ApplicationJob
  queue_as :critical

  # Thresholds for alerting
  THRESHOLDS = {
    jwt_denylist_max: 50_000,
    analytics_events_max: 10_000_000,
    dead_tuples_ratio_max: 0.1,  # 10% dead tuples
    connection_usage_max: 0.8    # 80% of pool
  }.freeze

  # Run every hour to check database health metrics
  # Alerts via Sentry if thresholds are exceeded
  #
  def perform
    metrics = gather_metrics
    alerts = check_thresholds(metrics)

    Rails.logger.info(
      event: "database_health_check",
      metrics: metrics,
      alerts: alerts
    )

    # Send alerts to Sentry
    if defined?(Sentry)
      alerts.each do |alert|
        Sentry.capture_message(
          "Database health alert: #{alert[:issue]}",
          level: :warning,
          extra: {
            metric: alert[:metric],
            current_value: alert[:value],
            threshold: alert[:threshold]
          }
        )
      end
    end

    { metrics: metrics, alerts: alerts }
  end

  private

  def gather_metrics
    {
      jwt_denylist_count: JwtDenylist.count,
      analytics_events_count: AnalyticsEvent.count,
      users_count: User.count,
      tasks_count: Task.unscoped.count,
      lists_count: List.unscoped.count,
      devices_count: Device.unscoped.count,
      connection_pool: connection_pool_stats,
      table_sizes: table_sizes
    }
  end

  def connection_pool_stats
    pool = ActiveRecord::Base.connection_pool
    {
      size: pool.size,
      connections: pool.connections.size,
      available: pool.stat[:available],
      usage_ratio: pool.connections.size.to_f / pool.size
    }
  end

  def table_sizes
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT#{' '}
        relname as table_name,
        pg_size_pretty(pg_total_relation_size(relid)) as total_size,
        pg_total_relation_size(relid) as size_bytes
      FROM pg_catalog.pg_statio_user_tables
      ORDER BY pg_total_relation_size(relid) DESC
      LIMIT 10
    SQL

    result.to_a
  rescue StandardError => e
    Rails.logger.error("Failed to get table sizes: #{e.message}")
    []
  end

  def check_thresholds(metrics)
    alerts = []

    if metrics[:jwt_denylist_count] > THRESHOLDS[:jwt_denylist_max]
      alerts << {
        issue: "JWT denylist too large",
        metric: "jwt_denylist_count",
        value: metrics[:jwt_denylist_count],
        threshold: THRESHOLDS[:jwt_denylist_max]
      }
    end

    if metrics[:analytics_events_count] > THRESHOLDS[:analytics_events_max]
      alerts << {
        issue: "Analytics events table too large",
        metric: "analytics_events_count",
        value: metrics[:analytics_events_count],
        threshold: THRESHOLDS[:analytics_events_max]
      }
    end

    pool = metrics[:connection_pool]
    if pool[:usage_ratio] > THRESHOLDS[:connection_usage_max]
      alerts << {
        issue: "Database connection pool usage high",
        metric: "connection_usage_ratio",
        value: pool[:usage_ratio],
        threshold: THRESHOLDS[:connection_usage_max]
      }
    end

    alerts
  end
end
