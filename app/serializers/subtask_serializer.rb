# frozen_string_literal: true

class SubtaskSerializer
  attr_reader :subtask

  def initialize(subtask)
    @subtask = subtask
  end

  def as_json
    {
      id: subtask.id,
      parent_task_id: subtask.parent_task_id,
      title: subtask.title,
      note: subtask.note,
      status: subtask.status,
      completed_at: completed_at_value,
      position: subtask.position,
      created_at: subtask.created_at.iso8601,
      updated_at: subtask.updated_at.iso8601
    }
  end

  private

  def completed_at_value
    if subtask.status == "done"
      subtask.completed_at&.iso8601 || subtask.updated_at.iso8601
    end
  end
end