# frozen_string_literal: true

module Health
  class Report
    READY_CHECK_KEYS = %w[database redis queue].freeze

    def self.live
      { ok: true }
    end

    def self.ready
      build(checks: CheckRegistry.ready)
    end

    def self.detailed
      build(checks: CheckRegistry.detailed, include_system: true)
    end

    def self.metrics
      results = CheckRegistry.ready.map(&:call)
      by_name = index_by_name(results)

      {
        health: healthy_results?(results) ? 1 : 0,
        database: healthy?(by_name["database"]) ? 1 : 0,
        redis: healthy?(by_name["redis"]) ? 1 : 0,
        queue: healthy?(by_name["queue"]) ? 1 : 0,
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

      return payload unless include_system

      payload.merge(
        version: System.version,
        environment: Rails.env,
        uptime_seconds: System.uptime_seconds,
        memory: System.memory
      )
    end

    private_class_method def self.healthy_results?(results)
      results.all? { |r| r[:status] == "healthy" }
    end

    private_class_method def self.index_by_name(results)
      results.each_with_object({}) do |r, h|
        h[r[:name].to_s] = r
      end
    end

    private_class_method def self.healthy?(result)
      result && result[:status] == "healthy"
    end

    private_class_method def self.monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    private_class_method def self.elapsed_ms(start)
      ((monotonic_time - start) * 1000).round(2)
    end
  end
end
