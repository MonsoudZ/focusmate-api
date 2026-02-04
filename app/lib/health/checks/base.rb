# frozen_string_literal: true

module Health
  module Checks
    class Base
      def call
        start = monotonic_time
        details = run

        {
          name: name,
          status: "healthy",
          response_time_ms: elapsed_ms(start),
          message: message,
          details: details
        }.compact
      rescue StandardError => e
        {
          name: name,
          status: "unhealthy",
          response_time_ms: nil,
          message: e.message,
          error: e.class.name
        }
      end

      def name
        self.class.name.split("::").last.downcase
      end

      def message
        "OK"
      end

      private

      def run
        nil
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def elapsed_ms(start)
        ((monotonic_time - start) * 1000).round(2)
      end
    end
  end
end
