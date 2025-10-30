# frozen_string_literal: true

class TaskCompletionService
  class UnauthorizedError < StandardError; end

  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def complete!
    validate_access!
    @task.complete!
    @task
  end

  def uncomplete!
    validate_access!
    @task.uncomplete!
    @task
  end

  def toggle_completion!(completed:)
    if completed == false || completed == "false"
      uncomplete!
    else
      complete!
    end
  end

  private

  def validate_access!
    return if can_access_task?

    raise UnauthorizedError, "You do not have permission to modify this task"
  end

  def can_access_task?
    # Check if user owns the list
    return true if @task.list.user_id == @user.id

    # Check if user created the task
    return true if @task.creator_id == @user.id

    # Check if user is a member/coach of the list
    return true if @task.list.memberships.exists?(user_id: @user.id)

    false
  end
end
