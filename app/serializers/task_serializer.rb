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
      due_at: task.due_at,
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
      missed_reason_submitted_at: task.missed_reason_submitted_at,

      # Recurring
      is_recurring: task.is_recurring || false,
      recurrence_pattern: task.recurrence_pattern,
      recurrence_interval: task.recurrence_interval || 1,
      recurrence_days: task.recurrence_days,
      template_id: task.template_id,
      instance_date: task.instance_date,
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

      # Visibility
      hidden: task.private_task?,

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
      created_at: task.created_at,
      updated_at: task.updated_at
    }

    # Include subtasks array if this is a parent task (not a subtask itself)
    if task.parent_task_id.nil? && options[:include_subtasks] != false
      result[:subtasks] = serialize_subtasks
    end

    # Include reschedule_events only when requested (to avoid N+1 in list views)
    if options[:include_reschedule_events] != false
      result[:reschedule_events] = serialize_reschedule_events
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
    @can_edit ||= use_fast_permission_path? ? fast_can_edit? : Permissions::TaskPermissions.can_edit?(task, current_user)
  end

  def can_delete?
    @can_delete ||= use_fast_permission_path? ? can_edit? : Permissions::TaskPermissions.can_delete?(task, current_user)
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
        completed_at: subtask.status == "done" ? iso8601_or_nil(subtask.completed_at || subtask.updated_at) : nil,
        position: subtask.position,
        created_at: subtask.created_at
      }
    end
  end

  def completed_at_value
    if task.status == "done"
      iso8601_or_nil(task.completed_at || task.updated_at)
    end
  end

  def iso8601_or_nil(value)
    value&.iso8601
  end

  # Use loaded tags if available
  def serialize_tags
    tags = task.tags.loaded? ? task.tags.to_a : task.tags
    tags.map { |t| { id: t.id, name: t.name, color: t.color } }
  end

  def serialize_reschedule_events
    events = if task.reschedule_events.loaded?
               task.reschedule_events.sort_by(&:created_at).reverse
    else
               task.reschedule_events.includes(:user).recent_first.to_a
    end

    events.map do |event|
      {
        id: event.id,
        task_id: event.task_id,
        previous_due_at: event.previous_due_at,
        new_due_at: event.new_due_at,
        reason: event.reason,
        rescheduled_by: event.user ? { id: event.user.id, name: event.user.name } : nil,
        created_at: event.created_at
      }
    end
  end

  def use_fast_permission_path?
    options[:editable_list_ids].present?
  end

  def fast_can_edit?
    return false if current_user.nil? || task.nil?
    return false if task.deleted? || task.list.nil?
    return false if task.private_task? && task.creator_id != current_user.id

    task.list.user_id == current_user.id ||
      task.creator_id == current_user.id ||
      options[:editable_list_ids].include?(task.list_id)
  end
end
