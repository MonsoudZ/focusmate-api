# frozen_string_literal: true

class TaskEventRecorder
  def initialize(task)
    @task = task
  end

  def record_creation(kind: nil, reason: nil, user: nil, occurred_at: nil)
    create_event(
      user: user || @task.list&.user || @task.creator,
      kind: kind || "created",
      reason: reason,
      occurred_at: occurred_at || Time.current
    )
  end

  def record_status_change
    kind = case @task.status
    when "done" then :completed
    when "pending" then :created
    else :created
    end
    record_creation(kind: kind)
  end

  def check_parent_completion
    return unless @task.parent_task && @task.parent_task.subtasks.pending.empty?
    if @task.parent_task.status == "pending"
      @task.parent_task.update!(status: :done)
    end
  end

  private

  def create_event(user:, kind:, reason:, occurred_at:)
    @task.task_events.create!(
      user: user,
      kind: kind,
      reason: reason,
      occurred_at: occurred_at
    )
  end
end
