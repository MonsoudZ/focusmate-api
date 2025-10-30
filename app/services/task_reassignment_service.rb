# frozen_string_literal: true

class TaskReassignmentService
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

  def reassign!(assigned_to_id:)
    validate_authorization!
    validate_assignment_support!
    perform_reassignment(assigned_to_id)
    @task
  end

  private

  def validate_authorization!
    unless @task.list.user_id == @user.id
      raise UnauthorizedError, "Only list owner can reassign tasks"
    end
  end

  def validate_assignment_support!
    return if Task.column_names.include?("assigned_to_id") || Task.column_names.include?("assigned_to")

    raise ValidationError.new("Task does not support assignment", { assigned_to: ["not supported"] })
  end

  def perform_reassignment(assigned_to_id)
    if Task.column_names.include?("assigned_to_id")
      @task.update!(assigned_to_id: assigned_to_id)
    elsif Task.column_names.include?("assigned_to")
      @task.update!(assigned_to: assigned_to_id)
    end
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError.new("Validation failed", e.record.errors.as_json)
  end
end
