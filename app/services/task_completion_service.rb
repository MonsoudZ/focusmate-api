# frozen_string_literal: true

# Service with multiple entry points - uses custom class methods
# instead of the standard .call! from ApplicationService
class TaskCompletionService < ApplicationService
  def self.complete!(task:, user:, missed_reason: nil)
    new(task:, user:, missed_reason:).complete!
  end

  def self.uncomplete!(task:, user:)
    new(task:, user:).uncomplete!
  end

  def self.toggle!(task:, user:, completed:, missed_reason: nil)
    new(task:, user:, missed_reason:).toggle_completion!(completed:)
  end

  def initialize(task:, user:, missed_reason: nil)
    @task = task
    @user = user
    @missed_reason = missed_reason
  end

  def complete!
    validate_access!
    validate_overdue_reason!

    @was_overdue = task_overdue?
    @minutes_overdue = calculate_minutes_overdue

    ActiveRecord::Base.transaction do
      if @missed_reason.present?
        @task.missed_reason = @missed_reason
        @task.missed_reason_submitted_at = Time.current
      end

      @task.complete!
      track_completion_analytics
    end

    enqueue_recurring_task_generation
    enqueue_streak_update

    @task
  end

  def uncomplete!
    validate_access!

    ActiveRecord::Base.transaction do
      @task.uncomplete!
      track_reopen_analytics
    end

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
    raise ApplicationError::Forbidden.new("You do not have permission to modify this task", code: "task_completion_forbidden")
  end

  def validate_overdue_reason!
    return unless task_requires_reason?
    return if @missed_reason.present?
    raise ApplicationError::UnprocessableEntity.new("This overdue task requires an explanation", code: "missing_reason")
  end

  def task_requires_reason?
    @task.requires_explanation_if_missed &&
      @task.due_at.present? &&
      @task.due_at < Time.current
  end

  def task_overdue?
    @task.due_at.present? && @task.due_at < Time.current
  end

  def calculate_minutes_overdue
    return 0 unless task_overdue?
    ((Time.current - @task.due_at) / 60).to_i
  end

  def can_access_task?
    return true if @task.list.user_id == @user.id
    return true if @task.creator_id == @user.id
    return true if @task.list.memberships.exists?(user_id: @user.id)
    false
  end

  def track_completion_analytics
    AnalyticsTracker.task_completed(
      @task,
      @user,
      was_overdue: @was_overdue,
      minutes_overdue: @minutes_overdue,
      missed_reason: @missed_reason
    )
  end

  def track_reopen_analytics
    AnalyticsTracker.task_reopened(@task, @user)
  end

  def enqueue_recurring_task_generation
    return unless @task.template_id.present?
    return unless @task.template&.is_template && @task.template&.template_type == "recurring"

    RecurringTaskInstanceJob.perform_later(user_id: @user.id, task_id: @task.id)
  end

  def enqueue_streak_update
    StreakUpdateJob.perform_later(user_id: @user.id)
  end
end
