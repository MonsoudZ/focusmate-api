# frozen_string_literal: true

class TaskUpdateService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(task:, user:)
    @task = task
    @user = user
  end

  def update!(attributes:)
    validate_authorization!
    perform_update(attributes)
    @task
  end

  private

  def validate_authorization!
    unless can_edit_task?
      raise UnauthorizedError, "You do not have permission to edit this task"
    end
  end

  def can_edit_task?
    return true if @task.list.user_id == @user.id
    return true if @task.creator_id == @user.id
    return true if @task.list.memberships.exists?(user_id: @user.id, role: "editor")
    false
  end

  def perform_update(attributes)
    unless @task.update(attributes)
      raise ValidationError.new("Validation failed", @task.errors.as_json)
    end
  end
end
