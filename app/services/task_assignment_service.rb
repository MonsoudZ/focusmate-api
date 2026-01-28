# frozen_string_literal: true

class TaskAssignmentService
  class Error < StandardError; end
  class BadRequest < Error; end
  class InvalidAssignee < Error; end

  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def assign!(assigned_to_id:)
    raise BadRequest, "assigned_to is required" if assigned_to_id.blank?

    assignee = User.find_by(id: assigned_to_id)
    unless assignee && @task.list.accessible_by?(assignee)
      raise InvalidAssignee, "User cannot be assigned to this task"
    end

    @task.update!(assigned_to_id: assigned_to_id)
    @task
  end

  def unassign!
    @task.update!(assigned_to_id: nil)
    @task
  end
end
