# frozen_string_literal: true

class TaskRescheduleService < ApplicationService
  def initialize(task:, user:, new_due_at:, reason:)
    @task = task
    @user = user
    @new_due_at = new_due_at
    @reason = reason
  end

  def call!
    validate_authorization!
    validate_inputs!

    ActiveRecord::Base.transaction do
      create_reschedule_event!
      update_task_due_date!
    end

    @task
  end

  private

  def validate_authorization!
    unless Permissions::TaskPermissions.can_edit?(@task, @user)
      raise ApplicationError::Forbidden.new("You do not have permission to reschedule this task", code: "task_reschedule_forbidden")
    end
  end

  def validate_inputs!
    if @new_due_at.blank?
      raise ApplicationError::BadRequest.new(
        "new_due_at is required",
        code: "missing_due_at"
      )
    end

    if @reason.blank?
      raise ApplicationError::BadRequest.new(
        "reason is required",
        code: "missing_reason"
      )
    end
  end

  def create_reschedule_event!
    @task.reschedule_events.create!(
      previous_due_at: @task.due_at,
      new_due_at: @new_due_at,
      reason: @reason,
      user: @user
    )
  end

  def update_task_due_date!
    @task.update!(due_at: @new_due_at)
  end
end
