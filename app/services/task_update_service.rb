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
    track_changes(attributes)
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

  def track_changes(attributes)
    @old_priority = @task.priority
    @old_starred = @task.starred
    @changes = attributes.keys.select { |k| @task.send(k) != attributes[k] }
  end

  def perform_update(attributes)
    unless @task.update(attributes)
      raise ValidationError.new("Validation failed", @task.errors.as_json)
    end

    track_analytics(attributes)
  end

  def track_analytics(attributes)
    # Track priority changes
    if attributes.key?(:priority) && @old_priority != @task.priority
      AnalyticsTracker.task_priority_changed(
        @task,
        @user,
        from: @old_priority,
        to: @task.priority
      )
    end

    # Track starred changes
    if attributes.key?(:starred) && @old_starred != @task.starred
      if @task.starred
        AnalyticsTracker.task_starred(@task, @user)
      else
        AnalyticsTracker.task_unstarred(@task, @user)
      end
    end

    # Track general edits (if other fields changed)
    other_changes = @changes - [ :priority, :starred ]
    if other_changes.any?
      AnalyticsTracker.task_edited(@task, @user, changes: other_changes)
    end
  end
end
