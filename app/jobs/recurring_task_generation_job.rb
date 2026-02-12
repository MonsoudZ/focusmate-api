# frozen_string_literal: true

class RecurringTaskGenerationJob < ApplicationJob
  include RateLimitedSentryReporting

  queue_as :default
  SENTRY_ERROR_TTL = 5.minutes

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
    templates_checked = 0
    skipped_deleted_list = 0
    skipped_pending_instance = 0
    skipped_no_instances = 0

    # Find all recurring templates
    templates = Task
                  .where(is_template: true, template_type: "recurring")
                  .where(deleted_at: nil)
                  .includes(:list, :creator)

    templates.find_in_batches do |batch|
      latest_instances_by_template = latest_instances_for_templates(batch.map(&:id))

      batch.each do |template|
        templates_checked += 1

        # Skip if template's list is deleted or missing (soft-deleted)
        if template.list.nil? || template.list.deleted?
          skipped_deleted_list += 1
          next
        end

        latest_instance = latest_instances_by_template[template.id]

        # Skip if there's a pending instance (not yet completed)
        if latest_instance && latest_instance.status != "done"
          skipped_pending_instance += 1
          next
        end

        # Skip templates with no instances yet
        unless latest_instance
          skipped_no_instances += 1
          next
        end

        begin
          service = RecurringTaskService.new(template.creator)
          generated_instance = service.generate_next_instance(latest_instance)
          generated_count += 1 if generated_instance
        rescue StandardError => e
          error_count += 1
          Rails.logger.error(
            event: "recurring_task_generation_failed",
            template_id: template.id,
            error_class: e.class.name,
            error_message: e.message
          )
          report_generation_error(e, template_id: template.id)
        end
      end
    end

    Rails.logger.info(
      event: "recurring_task_generation_completed",
      templates_checked: templates_checked,
      skipped_deleted_list: skipped_deleted_list,
      skipped_pending_instance: skipped_pending_instance,
      skipped_no_instances: skipped_no_instances,
      tasks_generated: generated_count,
      errors: error_count
    )

    {
      generated: generated_count,
      errors: error_count,
      skipped_deleted_list: skipped_deleted_list,
      skipped_pending_instance: skipped_pending_instance,
      skipped_no_instances: skipped_no_instances
    }
  end

  private

  def latest_instances_for_templates(template_ids)
    return {} if template_ids.empty?

    Task
      .where(template_id: template_ids, deleted_at: nil)
      .select("DISTINCT ON (template_id) tasks.*")
      .order("template_id ASC, due_at DESC, id DESC")
      .includes(:template)
      .index_by(&:template_id)
  end

  def report_generation_error(error, template_id:)
    digest = Digest::SHA256.hexdigest(error.message.to_s)[0, 16]
    cache_key = "recurring_task_generation_job:error:#{error.class.name}:#{digest}"

    report_error_once(
      error,
      cache_key: cache_key,
      ttl: SENTRY_ERROR_TTL,
      extra: { template_id: template_id }
    )
  end
end
