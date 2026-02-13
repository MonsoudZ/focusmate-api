# frozen_string_literal: true

class TaskUpdateService < ApplicationService
  ALLOWED_ATTRIBUTES = %i[
    title note due_at priority strict_mode visibility color starred position
    notification_interval_minutes is_recurring recurrence_pattern recurrence_interval
    recurrence_end_date recurrence_count recurrence_time recurrence_days tag_ids
  ].freeze

  def initialize(task:, user:, attributes:)
    @task = task
    @user = user
    @attributes = attributes.slice(*ALLOWED_ATTRIBUTES)
  end

  def call!
    validate_authorization!
    track_changes
    perform_update
    @task
  end

  private

  def validate_authorization!
    unless Permissions::TaskPermissions.can_edit?(@task, @user)
      raise ApplicationError::Forbidden.new("You do not have permission to edit this task", code: "task_update_forbidden")
    end
  end

  def track_changes
    @old_priority = @task.priority
    @old_starred = @task.starred
    @changes = @attributes.keys.select do |key|
      @task.respond_to?(key) && @task.public_send(key) != @attributes[key]
    end
  end

  def perform_update
    ActiveRecord::Base.transaction do
      unless @task.update(@attributes)
        raise ApplicationError::Validation.new("Validation failed", details: @task.errors.as_json)
      end

      track_analytics
    end
  end

  def track_analytics
    # Track priority changes
    if @attributes.key?(:priority) && @old_priority != @task.priority
      AnalyticsTracker.task_priority_changed(
        @task,
        @user,
        from: @old_priority,
        to: @task.priority
      )
    end

    # Track starred changes
    if @attributes.key?(:starred) && @old_starred != @task.starred
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
