# frozen_string_literal: true

class OrphanedAssignmentCleanupJob < ApplicationJob
  queue_as :maintenance

  # Finds and unassigns tasks where the assigned user no longer has access to the list.
  # This handles the rare race condition where a user is removed from a list
  # between task assignment validation and save.
  def perform
    orphaned_count = 0

    # Find all tasks with assignments
    Task.where.not(assigned_to_id: nil).where(deleted_at: nil).find_each do |task|
      next if user_has_access?(task)

      task.update_column(:assigned_to_id, nil)
      orphaned_count += 1

      Rails.logger.info(
        "OrphanedAssignmentCleanupJob: Unassigned task #{task.id} " \
        "(user #{task.assigned_to_id} no longer has access to list #{task.list_id})"
      )
    end

    { cleaned_up: orphaned_count }
  end

  private

  def user_has_access?(task)
    return false unless task.assigned_to_id
    return false unless task.list

    assignee = User.find_by(id: task.assigned_to_id)
    return false unless assignee

    task.list.accessible_by?(assignee)
  end
end
