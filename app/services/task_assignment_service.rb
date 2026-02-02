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
    end

    @task
  end

  def unassign!
    @task.update!(assigned_to_id: nil)
    @task
  end
end
