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
      # Skip if template's list is deleted
      next if template.list.deleted?

      # Check if we need to generate the next instance
      latest_instance = template.instances
                                .where(deleted_at: nil)
                                .where.not(status: "done")
                                .order(due_at: :desc)
                                .first

      # If no pending instance exists, generate one
      if latest_instance.nil?
        begin
          service = RecurringTaskService.new(template.creator)
          last_completed = template.instances
                                   .where(status: "done")
                                   .order(due_at: :desc)
                                   .first

          if last_completed
            service.generate_next_instance(last_completed)
            generated_count += 1
          end
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