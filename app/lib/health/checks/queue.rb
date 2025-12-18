# frozen_string_literal: true

module Health
  module Checks
    class Queue < Base
      def message = "Queue operational"

      private

      def run
        raise "Sidekiq not loaded" unless defined?(Sidekiq)

        {
          queue_size: Sidekiq::Queue.new.size,
          dead_jobs: Sidekiq::DeadSet.new.size
        }
      end
    end
  end
end
