# frozen_string_literal: true

class OverdueScanJob
  include Sidekiq::Job

  sidekiq_options queue: :maintenance, retry: 2, backtrace: true

  # since_minutes: how far back to consider tasks overdue (default: 10 minutes)
  # batch_size: how many task IDs to enqueue per Sidekiq bulk push (default: 1000)
  def perform(since_minutes = 10, batch_size: 1_000)
    Notifications::OverdueScanner.call!(
      since_minutes: since_minutes,
      batch_size: batch_size
    )
  end
end
