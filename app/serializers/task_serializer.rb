# app/serializers/task_serializer.rb
class TaskSerializer
  attr_reader :task, :current_user, :options

  def initialize(task, current_user:, **options)
    @task = task
    @current_user = current_user
    @options = options
  end

  def as_json
    {
      id: task.id,
      list_id: task.list_id,
      title: task.title,
      description: task.note,
      due_at: task.due_at&.iso8601,
      completed_at: completed_at_value,
      priority: derive_priority,
      can_be_snoozed: !task.strict_mode,
      notification_interval_minutes: task.notification_interval_minutes || 10,
      requires_explanation_if_missed: task.requires_explanation_if_missed || false,
      
      # Status flags
      overdue: overdue?,
      minutes_overdue: minutes_overdue,
      requires_explanation: requires_explanation?,
      
      # Recurring
      is_recurring: task.is_recurring || false,
      recurrence_pattern: task.recurrence_pattern,
      recurrence_interval: task.recurrence_interval || 1,
      recurrence_days: task.recurrence_days,
      
      # Location
      location_based: task.location_based || false,
      location_name: task.location_name,
      location_latitude: task.location_latitude&.to_f,
      location_longitude: task.location_longitude&.to_f,
      location_radius_meters: task.location_radius_meters || 100,
      notify_on_arrival: task.notify_on_arrival.nil? ? true : task.notify_on_arrival,
      notify_on_departure: task.notify_on_departure || false,
      
      # Accountability
      missed_reason: task.missed_reason,
      missed_reason_submitted_at: task.missed_reason_submitted_at&.iso8601,
      missed_reason_reviewed_at: task.missed_reason_reviewed_at&.iso8601,
      
      # Creator
      creator: creator_data,
      created_by_coach: created_by_coach?,
      
      # Permissions
      can_edit: can_edit?,
      can_delete: can_delete?,
      can_complete: can_complete?,
      
      # Escalation
      escalation: escalation_data,
      
      # Subtasks
      has_subtasks: has_subtasks?,
      subtasks_count: subtasks_count,
      subtasks_completed_count: subtasks_completed_count,
      subtask_completion_percentage: subtask_percentage,
      
      # Timestamps
      created_at: task.created_at.iso8601,
      updated_at: task.updated_at.iso8601
    }
  end

  private

  def derive_priority
    return 3 if task.strict_mode && overdue?  # Urgent
    return 2 if task.strict_mode               # High
    return 1 if task.due_at && task.due_at < 24.hours.from_now  # Medium
    0  # Low
  end

  def overdue?
    # Task is overdue if it has a due date in the past and is NOT completed
    task.due_at.present? && 
    task.due_at < Time.current && 
    (task.status.nil? || task.status == 0 || task.status == 'incomplete')
  end

  def minutes_overdue
    return 0 unless overdue?
    ((Time.current - task.due_at) / 60).to_i
  end

  def requires_explanation?
    task.requires_explanation_if_missed && overdue? && task.missed_reason.nil?
  end

  def creator_data
    creator = task.creator || task.list.owner
    return {} unless creator
    
    {
      id: creator.id,
      email: creator.email,
      name: creator.name,
      role: creator.role
    }
  end

  def created_by_coach?
    task.creator_id.present? && task.creator_id != task.list.user_id
  end

  def can_edit?
    return true if task.creator_id == current_user.id
    return true if task.list.user_id == current_user.id
    false
  end

  def can_delete?
    return true if task.creator_id == current_user.id
    return true if task.list.user_id == current_user.id
    false
  end

  def can_complete?
    task.list.user_id == current_user.id
  end

  def escalation_data
    return nil unless task.escalation
    
    {
      level: task.escalation.escalation_level,
      notification_count: task.escalation.notification_count,
      blocking_app: task.escalation.blocking_app,
      coaches_notified: task.escalation.coaches_notified,
      became_overdue_at: task.escalation.became_overdue_at&.iso8601,
      last_notification_at: task.escalation.last_notification_at&.iso8601
    }
  end

  def has_subtasks?
    task.subtasks.any?
  end

  def subtasks_count
    task.subtasks.count
  end

  def subtasks_completed_count
    task.subtasks.complete.count
  end

  def subtask_percentage
    return 0 if subtasks_count.zero?
    (subtasks_completed_count.to_f / subtasks_count * 100).round
  end

  def completed_at_value
    # Handle nil, 0, and 1
    if task.status == 1 || task.status == 'complete'
      task.updated_at.iso8601
    else
      nil
    end
  end
end