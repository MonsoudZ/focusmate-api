# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Database deadlocks are transient
  retry_on ActiveRecord::Deadlocked, wait: :exponentially_longer, attempts: 3

  # If a record was deleted before the job runs, drop it
  discard_on ActiveJob::DeserializationError

  # Retry only known transient network errors (not all StandardError)
  TRANSIENT_ERRORS = [
    Timeout::Error,
    Errno::ECONNRESET,
    Errno::ECONNREFUSED,
    Errno::ETIMEDOUT,
    SocketError,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze

  TRANSIENT_ERRORS.each do |klass|
    retry_on klass, wait: :exponentially_longer, attempts: 3
  end
end
