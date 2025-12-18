# frozen_string_literal: true

class NudgeJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 3, backtrace: true

  sidekiq_retry_in do |count, exception|
    case exception
    when ActiveRecord::RecordNotFound
      0 # task/user/list deleted -> don't retry
    else
      # backoff: 30s, 60s, 90s (capped)
      [30 * (count + 1), 300].min
    end
  end

  def perform(task_id, reason = nil, options = {})
    Notifications::TaskNudge.call!(
      task_id: task_id,
      reason: reason,
      options: options || {}
    )
  end

  class << self
    def enqueue_for_task(task_id, reason = nil, options = {})
      perform_async(task_id, reason, options)
    end

    def enqueue_for_task_with_delay(task_id, reason = nil, delay_seconds = 0, options = {})
      perform_in(delay_seconds, task_id, reason, options)
    end

    def enqueue_for_task_at(task_id, reason = nil, at_time = nil, options = {})
      perform_at(at_time, task_id, reason, options)
    end
  end
end

