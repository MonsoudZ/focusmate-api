# frozen_string_literal: true

module Health
  class Report
    def self.live
      { ok: true }
    end

    def self.ready
      build(checks: Checks.ready_checks)
    end

    def self.detailed
      build(checks: Checks.detailed_checks, include_system: true)
    end

    def self.metrics
      checks = Checks.ready_checks.map(&:call)
      {
        health: healthy_results?(checks) ? 1 : 0,
        database: checks.find { |c| c[:name] == "database" }&.dig(:status) == "healthy" ? 1 : 0,
        redis: checks.find { |c| c[:name] == "redis" }&.dig(:status) == "healthy" ? 1 : 0,
        queue: checks.find { |c| c[:name] == "queue" }&.dig(:status) == "healthy" ? 1 : 0,
        timestamp: Time.current.to_i
      }
    end

    def self.http_status(report)
      report[:status] == "healthy" ? :ok : :service_unavailable
    end

    private_class_method def self.build(checks:, include_system: false)
      start = monotonic_time
      results = checks.map(&:call)

      payload = {
        status: healthy_results?(results) ? "healthy" : "degraded",
        timestamp: Time.current.iso8601,
        duration_ms: elapsed_ms(start),
        checks: results
      }

      if include_system
        payload.merge!(
          version: System.version,
          environment: Rails.env,
          uptime_seconds: System.uptime_seconds,
          memory: System.memory
        )
      end

      payload
    end

    private_class_method def self.healthy_results?(results)
      results.all? { |r| r[:status] == "healthy" }
    end

    private_class_method def self.monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    private_class_method def self.elapsed_ms(start)
      ((monotonic_time - start) * 1000).round(2)
    end
  end
end
