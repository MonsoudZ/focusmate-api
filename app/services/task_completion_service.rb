# frozen_string_literal: true

class TaskCompletionService
  class UnauthorizedError < StandardError; end
  class MissingReasonError < StandardError; end

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

    if @missed_reason.present?
      @task.missed_reason = @missed_reason
      @task.missed_reason_submitted_at = Time.current
    end

    @task.complete!
    track_completion_analytics
    @task
  end

  def uncomplete!
    validate_access!
    @task.uncomplete!
    track_reopen_analytics
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

  def validate_overdue_reason!
    return unless task_requires_reason?
    return if @missed_reason.present?
    raise MissingReasonError, "This overdue task requires an explanation"
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
end