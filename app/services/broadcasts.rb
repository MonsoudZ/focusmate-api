module Broadcasts
  module_function

  def task_changed(task, event:, current_user: nil)
    # Use TaskSerializer for consistent JSON structure
    # If no current_user provided, create a minimal payload
    if current_user
      task_payload = TaskSerializer.new(task, current_user: current_user).as_json
    else
      # Create a basic payload without user-specific fields
      task_payload = {
        id: task.id,
        list_id: task.list_id,
        title: task.title,
        description: task.note,
        due_at: task.due_at&.iso8601,
        completed_at: task.completed_at&.iso8601,
        can_be_snoozed: !task.strict_mode,
        notification_interval_minutes: task.notification_interval_minutes || 10,
        requires_explanation_if_missed: task.requires_explanation_if_missed || false,
        overdue: task.overdue?,
        minutes_overdue: task.minutes_overdue,
        requires_explanation: task.requires_explanation?,
        is_recurring: task.is_recurring || false,
        recurrence_pattern: task.recurrence_pattern,
        recurrence_interval: task.recurrence_interval || 1,
        recurrence_days: task.recurrence_days,
        location_based: task.location_based || false,
        location_name: task.location_name,
        location_latitude: task.location_latitude&.to_f,
        location_longitude: task.location_longitude&.to_f,
        location_radius_meters: task.location_radius_meters || 100,
        notify_on_arrival: task.notify_on_arrival.nil? ? true : task.notify_on_arrival,
        notify_on_departure: task.notify_on_departure || false,
        missed_reason: task.missed_reason,
        missed_reason_submitted_at: task.missed_reason_submitted_at&.iso8601,
        missed_reason_reviewed_at: task.missed_reason_reviewed_at&.iso8601,
        creator: {
          id: task.creator.id,
          name: task.creator.name,
          email: task.creator.email
        },
        created_at: task.created_at.iso8601,
        updated_at: task.updated_at.iso8601,
        visibility: task.visibility,
        can_change_visibility: false, # Default to false when no user context
        can_edit: false, # Default to false when no user context
        can_complete: false, # Default to false when no user context
        can_delete: false # Default to false when no user context
      }
    end
    
    ListChannel.broadcast_to(
      task.list,
      {
        type: "task.#{event}",
        task: task_payload,
        timestamp: Time.current.iso8601
      }
    )
  end

  # Normalized task.updated event with full payload
  def task_updated(task, current_user: nil)
    task_changed(task, event: "updated", current_user: current_user)
  end

  # Other normalized events
  def task_created(task, current_user: nil)
    task_changed(task, event: "created", current_user: current_user)
  end

  def task_deleted(task, current_user: nil)
    task_changed(task, event: "deleted", current_user: current_user)
  end

  def task_completed(task, current_user: nil)
    task_changed(task, event: "completed", current_user: current_user)
  end
end
