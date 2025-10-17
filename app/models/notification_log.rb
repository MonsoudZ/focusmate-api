class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true
  
  validates :notification_type, presence: true
  validates :delivered, inclusion: { in: [true, false] }
  
  # Scopes
  scope :delivered, -> { where(delivered: true) }
  scope :undelivered, -> { where(delivered: false) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Check if notification was delivered
  def delivered?
    delivered
  end
  
  # Mark as delivered
  def mark_delivered!
    update!(delivered: true, delivered_at: Time.current)
  end
  
  # Get notification metadata
  def metadata
    super || {}
  end
  
  # Set notification metadata
  def metadata=(value)
    super(value.to_json) if value.present?
  end
  
  # Get parsed metadata
  def parsed_metadata
    return {} if metadata.blank?
    JSON.parse(metadata) rescue {}
  end

  # Check if notification is read
  def read?
    parsed_metadata['read'] == true
  end

  # Mark as read
  def mark_read!
    current_metadata = parsed_metadata
    current_metadata['read'] = true
    update!(metadata: current_metadata)
  end

  # Get notification summary for display
  def summary
    {
      id: id,
      type: notification_type,
      message: message,
      delivered: delivered,
      read: read?,
      created_at: created_at
    }
  end

  # Get notification details for display
  def details
    {
      id: id,
      type: notification_type,
      message: message,
      delivered: delivered,
      delivered_at: delivered_at,
      read: read?,
      task: task ? {
        id: task.id,
        title: task.title,
        due_at: task.due_at,
        status: task.status
      } : nil,
      metadata: parsed_metadata,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Get notification age in hours
  def age_hours
    ((Time.current - created_at) / 1.hour).round(1)
  end

  # Check if notification is recent (within last 24 hours)
  def recent?
    created_at > 24.hours.ago
  end

  # Get notification priority based on type
  def priority
    case notification_type
    when 'task_overdue', 'task_escalated'
      'high'
    when 'task_due_soon', 'coaching_invitation'
      'medium'
    else
      'low'
    end
  end
end
