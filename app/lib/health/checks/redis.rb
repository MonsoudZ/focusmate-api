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
        if defined?(Sidekiq)
          Sidekiq.redis { |connection| connection.ping }
        else
          redis = ::Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0"))
          begin
            redis.ping
          ensure
            redis.close
          end
        end
      end
    end
  end
end
