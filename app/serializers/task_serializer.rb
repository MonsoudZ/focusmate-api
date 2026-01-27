# frozen_string_literal: true

class TaskSerializer
  attr_reader :task, :current_user, :options

  def initialize(task, current_user:, **options)
    @task = task
    @current_user = current_user
    @options = options
  end

  def as_json
    result = {
      id: task.id,
      list_id: task.list_id,
      list_name: task.list.name,
      color: task.color,
      title: task.title,
      note: task.note,
      due_at: task.due_at&.iso8601,
      completed_at: completed_at_value,
      priority: Task.priorities[task.priority],
      starred: task.starred,
      position: task.position,
      tags: serialize_tags,
      notification_interval_minutes: task.notification_interval_minutes || 10,
      status: task.status,
      overdue: overdue?,
      minutes_overdue: minutes_overdue,
      requires_explanation_if_missed: task.requires_explanation_if_missed || false,
      missed_reason: task.missed_reason,
      missed_reason_submitted_at: task.missed_reason_submitted_at&.iso8601,

      # Recurring
      is_recurring: task.is_recurring || false,
      recurrence_pattern: task.recurrence_pattern,
      recurrence_interval: task.recurrence_interval || 1,
      recurrence_days: task.recurrence_days,
      template_id: task.template_id,
      instance_date: task.instance_date&.iso8601,
      instance_number: task.instance_number,

      # Location
      location_based: task.location_based || false,
      location_name: task.location_name,
      location_latitude: task.location_latitude&.to_f,
      location_longitude: task.location_longitude&.to_f,
      location_radius_meters: task.location_radius_meters || 100,
      notify_on_arrival: task.notify_on_arrival.nil? ? true : task.notify_on_arrival,
      notify_on_departure: task.notify_on_departure || false,

      # Creator
      creator: creator_data,

      # Permissions
      can_edit: can_edit?,
      can_delete: can_delete?,

      # Subtasks metadata
      parent_task_id: task.parent_task_id,
      has_subtasks: has_subtasks?,
      subtasks_count: subtasks_count,
      subtasks_completed_count: subtasks_completed_count,
      subtask_completion_percentage: subtask_percentage,

      # Timestamps
      created_at: task.created_at.iso8601,
      updated_at: task.updated_at.iso8601
    }

    # Include subtasks array if this is a parent task (not a subtask itself)
    if task.parent_task_id.nil? && options[:include_subtasks] != false
      result[:subtasks] = serialize_subtasks
    end

    result
  end

  private

  def overdue?
    task.due_at.present? &&
      task.due_at < Time.current &&
      (task.status.nil? || task.status == "pending" || task.status == "in_progress")
  end

  def minutes_overdue
    return 0 unless overdue?
    ((Time.current - task.due_at) / 60).to_i
  end

  def creator_data
    creator = task.creator || task.list.user
    return {} unless creator

    {
      id: creator.id,
      email: creator.email,
      name: creator.name,
      role: creator.role
    }
  end

  def can_edit?
    task.creator_id == current_user.id || task.list.user_id == current_user.id
  end

  def can_delete?
    can_edit?
  end

  # Use memoized subtasks collection to avoid N+1 queries
  def subtasks_collection
    @subtasks_collection ||= if task.subtasks.loaded?
                               task.subtasks.reject(&:deleted?).sort_by { |s| s.position || 0 }
                             else
                               task.subtasks.where(deleted_at: nil).order(:position).to_a
                             end
  end

  def has_subtasks?
    subtasks_collection.any?
  end

  def subtasks_count
    subtasks_collection.size
  end

  def subtasks_completed_count
    subtasks_collection.count { |s| s.status == "done" }
  end

  def subtask_percentage
    return 0 if subtasks_count.zero?
    (subtasks_completed_count.to_f / subtasks_count * 100).round
  end

  def serialize_subtasks
    subtasks_collection.map do |subtask|
      {
        id: subtask.id,
        title: subtask.title,
        note: subtask.note,
        status: subtask.status,
        completed_at: subtask.status == "done" ? (subtask.completed_at&.iso8601 || subtask.updated_at.iso8601) : nil,
        position: subtask.position,
        created_at: subtask.created_at.iso8601
      }
    end
  end

  def completed_at_value
    if task.status == "done"
      task.completed_at&.iso8601 || task.updated_at.iso8601
    end
  end

  # Use loaded tags if available
  def serialize_tags
    tags = task.tags.loaded? ? task.tags.to_a : task.tags
    tags.map { |t| { id: t.id, name: t.name, color: t.color } }
  end
end