# frozen_string_literal: true

module Health
  module Checks
    class Redis < Base
      def message = "Redis responsive"

      private

      def run
        client = redis_client
        resp = client.ping
        raise "Unexpected response: #{resp}" unless resp == "PONG"
        nil
      end

      def redis_client
        return Redis.current if defined?(Redis.current)

        if defined?(Sidekiq)
          Sidekiq.redis { |c| c }
        else
          Redis.new
        end
      end
    end
  end
end
