# frozen_string_literal: true

class OrphanedAssignmentCleanupJob < ApplicationJob
  queue_as :maintenance

  # Finds and unassigns tasks where the assigned user no longer has access to the list.
  # This handles the rare race condition where a user is removed from a list
  # between task assignment validation and save.
  def perform
    orphaned_count = 0
    timestamp = Time.current

    orphaned_tasks.in_batches(of: 1000) do |batch|
      orphaned_count += batch.update_all(assigned_to_id: nil, updated_at: timestamp)
    end

    Rails.logger.info(event: "orphaned_assignment_cleanup_completed", cleaned_up: orphaned_count)

    { cleaned_up: orphaned_count }
  end

  private

  def orphaned_tasks
    Task
      .joins(:list)
      .joins("LEFT JOIN memberships ON memberships.list_id = tasks.list_id AND memberships.user_id = tasks.assigned_to_id")
      .where(tasks: { deleted_at: nil })
      .where.not(assigned_to_id: nil)
      .where("tasks.assigned_to_id <> lists.user_id")
      .where("memberships.id IS NULL")
  end
end
