# frozen_string_literal: true

class SubtaskManagementService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(parent_task:, user:)
    @parent_task = parent_task
    @user = user
  end

  def create_subtask!(title:, note: nil, due_at: nil)
    validate_authorization!
    validate_due_at!(due_at)

    subtask = build_subtask(title: title, note: note, due_at: due_at)

    if subtask.save
      subtask
    else
      raise ValidationError.new("Validation failed", subtask.errors.as_json)
    end
  end

  def update_subtask!(subtask:, attributes:)
    validate_authorization!

    if subtask.update(attributes)
      subtask
    else
      raise ValidationError.new("Validation failed", subtask.errors.as_json)
    end
  end

  def delete_subtask!(subtask:)
    validate_authorization!
    subtask.destroy
    true
  end

  private

  def validate_authorization!
    unless @parent_task.list.user_id == @user.id
      raise UnauthorizedError, "Only list owner can manage subtasks"
    end
  end

  def validate_due_at!(due_at)
    # Check if due_at is required and missing
    if Task.validators_on(:due_at).any? { |v| v.kind == :presence } && due_at.nil?
      raise ValidationError.new(
        "Validation failed",
        { due_at: ["is invalid or missing"] }
      )
    end
  end

  def build_subtask(title:, note:, due_at:)
    subtask_attrs = {
      title: title,
      note: note,
      due_at: due_at,
      list_id: @parent_task.list_id,
      creator_id: @user.id,
      strict_mode: true
    }

    # Set parent relationship
    if Task.column_names.include?("parent_task_id")
      subtask_attrs[:parent_task_id] = @parent_task.id
    end

    Task.new(subtask_attrs)
  end
end
