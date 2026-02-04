# frozen_string_literal: true

module Health
  module Checks
    class Redis < Base
      def message = "Redis responsive"

      private

      def run
        resp = ping_response
        raise "Unexpected response: #{resp}" unless resp == "PONG"
        nil
      end

      def ping_response
        current = Redis.current if Redis.respond_to?(:current)
        return current.ping if current

        if defined?(Sidekiq)
          Sidekiq.redis { |connection| connection.ping }
        else
          Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")).ping
        end
      end
    end
  end
end
