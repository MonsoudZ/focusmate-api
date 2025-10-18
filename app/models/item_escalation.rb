class ItemEscalation < ApplicationRecord
  belongs_to :task

  validates :escalation_level, presence: true, inclusion: { in: %w[normal warning critical blocking] }
  validates :task_id, uniqueness: true

  # Scopes
  scope :normal, -> { where(escalation_level: "normal") }
  scope :warning, -> { where(escalation_level: "warning") }
  scope :critical, -> { where(escalation_level: "critical") }
  scope :blocking, -> { where(escalation_level: "blocking") }
  scope :blocking_app, -> { where(blocking_app: true) }

  # Check if escalation is at a specific level
  def normal?
    escalation_level == "normal"
  end

  def warning?
    escalation_level == "warning"
  end

  def critical?
    escalation_level == "critical"
  end

  def blocking?
    escalation_level == "blocking"
  end

  # Escalate to next level
  def escalate!
    case escalation_level
    when "normal"
      update!(escalation_level: "warning")
    when "warning"
      update!(escalation_level: "critical")
    when "critical"
      update!(escalation_level: "blocking", blocking_app: true, blocking_started_at: Time.current)
    end
  end

  # Reset escalation
  def reset!
    update!(
      escalation_level: "normal",
      notification_count: 0,
      last_notification_at: nil,
      became_overdue_at: nil,
      coaches_notified: false,
      coaches_notified_at: nil,
      blocking_app: false,
      blocking_started_at: nil
    )
  end

  # Mark coaches as notified
  def notify_coaches!
    update!(
      coaches_notified: true,
      coaches_notified_at: Time.current
    )
  end

  # Increment notification count
  def increment_notifications!
    increment!(:notification_count)
    update!(last_notification_at: Time.current)
  end

  # Set overdue timestamp
  def mark_overdue!
    update!(became_overdue_at: Time.current) unless became_overdue_at.present?
  end

  # Clear escalation (alias for reset!)
  def clear!
    reset!
  end
end
