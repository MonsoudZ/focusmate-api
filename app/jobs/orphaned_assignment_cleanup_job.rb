# frozen_string_literal: true

class OrphanedAssignmentCleanupJob < ApplicationJob
  queue_as :maintenance

  # Finds and unassigns tasks where the assigned user no longer has access to the list.
  # This handles the rare race condition where a user is removed from a list
  # between task assignment validation and save.
  def perform
    orphaned_count = 0

    # Preload associations to avoid N+1 queries
    # - assigned_to: the user assigned to the task
    # - list: the task's list (for owner check)
    # - list.memberships: for membership-based access check
    tasks_scope = Task
      .where.not(assigned_to_id: nil)
      .where(deleted_at: nil)
      .includes(:assigned_to, list: :memberships)

    tasks_scope.find_each do |task|
      next if user_has_access?(task)

      old_assigned_to_id = task.assigned_to_id
      task.update_column(:assigned_to_id, nil)
      orphaned_count += 1

      Rails.logger.info(
        "OrphanedAssignmentCleanupJob: Unassigned task #{task.id} " \
        "(user #{old_assigned_to_id} no longer has access to list #{task.list_id})"
      )
    end

    { cleaned_up: orphaned_count }
  end

  private

  def user_has_access?(task)
    assignee = task.assigned_to
    return false unless assignee
    return false unless task.list

    # Check access using preloaded data
    # Owner always has access
    return true if task.list.user_id == assignee.id

    # Check membership (uses preloaded memberships)
    task.list.memberships.any? { |m| m.user_id == assignee.id }
  end
end
