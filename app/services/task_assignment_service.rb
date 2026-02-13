# frozen_string_literal: true

# Service with multiple entry points - uses custom class methods
class TaskAssignmentService < ApplicationService
  def self.assign!(task:, user:, assigned_to_id:)
    new(task:, user:).assign!(assigned_to_id:)
  end

  def self.unassign!(task:, user:)
    new(task:, user:).unassign!
  end

  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def assign!(assigned_to_id:)
    validate_edit_permission!
    raise ApplicationError::BadRequest, "assigned_to is required" if assigned_to_id.blank?

    assignee = User.find_by(id: assigned_to_id)
    raise ApplicationError::UnprocessableEntity.new("User not found", code: "invalid_assignee") unless assignee

    ActiveRecord::Base.transaction do
      # Lock the list to prevent concurrent membership changes
      @task.list.lock!

      unless @task.list.accessible_by?(assignee)
        raise ApplicationError::UnprocessableEntity.new("User cannot be assigned to this task", code: "invalid_assignee")
      end

      @task.update!(assigned_to_id: assigned_to_id)

      # Enqueue inside transaction — Solid Queue uses the same DB,
      # so the job commits atomically with the assignment.
      if assignee.id != @user.id
        SendTaskAssignedNotificationJob.perform_later(task_id: @task.id, assigned_by_id: @user.id)
      end
    end

    @task
  end

  def unassign!
    validate_edit_permission!
    @task.update!(assigned_to_id: nil)
    @task
  end

  private

  def validate_edit_permission!
    unless Permissions::TaskPermissions.can_edit?(@task, @user)
      raise ApplicationError::Forbidden.new("You do not have permission to modify this task", code: "task_update_forbidden")
    end
  end
end
