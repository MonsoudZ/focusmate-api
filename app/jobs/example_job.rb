# frozen_string_literal: true

class ExampleJob < ApplicationJob
  queue_as :default

  def perform(message)
    Rails.logger.info "Processing job with message: #{message}"
    # Simulate some work
    sleep(2)
    Rails.logger.info "Job completed successfully"
  end
end
