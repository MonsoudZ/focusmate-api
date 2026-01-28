# frozen_string_literal: true

class RecurringTaskGenerationJob < ApplicationJob
  queue_as :default

  # Run every hour to generate upcoming recurring task instances
  # This ensures users see their recurring tasks even if they don't
  # complete the previous instance
  #
  # Schedule with sidekiq-cron:
  #   RecurringTaskGenerationJob.perform_later
  #
  def perform
    generated_count = 0
    error_count = 0

    # Find all recurring templates
    templates = Task
                  .where(is_template: true, template_type: "recurring")
                  .where(deleted_at: nil)
                  .includes(:list, :creator)

    templates.find_each do |template|
      # Skip if template's list is deleted or missing (soft-deleted)
      next if template.list.nil? || template.list.deleted?

      # Single query: get most recent instance (any status)
      # This replaces two separate queries (pending + completed)
      latest_instance = template.instances
                                .where(deleted_at: nil)
                                .order(due_at: :desc)
                                .first

      # Skip if there's a pending instance (not yet completed)
      next if latest_instance && latest_instance.status != "done"

      # Generate next instance if last one was completed (or no instances exist yet)
      next unless latest_instance # Skip templates with no instances yet

      begin
        service = RecurringTaskService.new(template.creator)
        service.generate_next_instance(latest_instance)
        generated_count += 1
      rescue StandardError => e
        error_count += 1
        Rails.logger.error(
          event: "recurring_task_generation_failed",
          template_id: template.id,
          error: e.message
        )
        Sentry.capture_exception(e, extra: { template_id: template.id })
      end
    end

    Rails.logger.info(
      event: "recurring_task_generation_completed",
      templates_checked: templates.count,
      tasks_generated: generated_count,
      errors: error_count
    )

    { generated: generated_count, errors: error_count }
  end
end
