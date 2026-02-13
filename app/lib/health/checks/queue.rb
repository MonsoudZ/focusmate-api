# frozen_string_literal: true

module Health
  module Checks
    class Queue < Base
      def message = "Queue operational"

      private

      def run
        {
          pending_jobs: SolidQueue::Job.where(finished_at: nil).count,
          failed_jobs: SolidQueue::FailedExecution.count
        }
      end
    end
  end
end
