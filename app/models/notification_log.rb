class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  validates :notification_type, presence: true, length: { maximum: 100 }
  validates :notification_type, inclusion: { in: %w[urgent_alert task_reminder system_announcement coaching_message test_notification old_notification new_notification bulk_notification complex_notification nil_metadata empty_metadata special_chars long_content unicode], allow_nil: false }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :delivered, inclusion: { in: [ true, false ], message: "must be a boolean value" }
  validates :delivery_method, inclusion: { in: %w[email push sms in_app], allow_nil: true }
  validate :validate_metadata_json

  before_validation { self.delivered = false if delivered.nil? }

  def validate_metadata_json
    return if read_attribute(:metadata).nil?
    return if read_attribute(:metadata).is_a?(Hash)

    if read_attribute(:metadata).is_a?(String)
      begin
        JSON.parse(read_attribute(:metadata))
      rescue JSON::ParserError
        errors.add(:metadata, "is not a valid JSON")
      end
    end
  end

  # Soft deletion
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Scopes
  scope :for_user, ->(u) { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :for_task, ->(t) { where(task_id: t.is_a?(Task) ? t.id : t) }
  scope :recent, -> { where(created_at: 1.week.ago..).order(created_at: :desc) }
  scope :delivered, -> { where(delivered: true) }
  scope :undelivered, -> { where(delivered: false) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :read, -> { where("metadata->>'read' = 'true'") }
  scope :unread, -> { where("metadata->>'read' IS NULL OR metadata->>'read' != 'true'") }

  # Metadata handling
  def metadata
    raw = read_attribute(:metadata)
    case raw
    when Hash then raw
    when String then JSON.parse(raw) rescue {}
    else {}
    end
  end

  def metadata=(value)
    case value
    when nil then write_attribute(:metadata, {})
    when Hash then write_attribute(:metadata, value)
    when String then write_attribute(:metadata, value)
    else write_attribute(:metadata, {})
    end
  end

  # Core methods
  def read?
    metadata["read"] == true
  end

  def undelivered?
    delivered == false
  end

  def mark_read!
    m = metadata.dup
    m["read"] = true
    update!(metadata: m)
  end

  def mark_undelivered!
    update!(delivered: false, delivered_at: nil)
  end

  def mark_delivered!
    update!(delivered: true, delivered_at: Time.current)
  end

  # Summary and detail methods
  def summary
    {
      id: id,
      notification_type: notification_type,
      message: message,
      delivered: delivered,
      metadata: metadata
    }
  end

  def details
    {
      id: id,
      notification_type: notification_type,
      message: message,
      delivered: delivered,
      delivery_method: delivery_method,
      metadata: metadata
    }
  end

  # Age and recency methods
  def age_hours
    return 0 unless created_at
    ((Time.current - created_at) / 1.hour).round(2)
  end

  def recent?
    return false unless created_at
    created_at > 1.hour.ago
  end

  # Priority based on notification type
  def priority
    case notification_type
    when "urgent_alert"
      "high"
    when "task_reminder", "coaching_message"
      "medium"
    when "system_announcement"
      "low"
    else
      "medium"
    end
  end

  # Category based on notification type
  def category
    case notification_type
    when "task_reminder"
      "task"
    when "system_announcement"
      "system"
    when "coaching_message"
      "coaching"
    when "urgent_alert"
      "alert"
    else
      "other"
    end
  end

  # Check if notification requires action
  def actionable?
    case notification_type
    when "task_reminder", "coaching_message", "urgent_alert"
      true
    when "system_announcement"
      false
    else
      false
    end
  end

  # Notification data structure
  def notification_data
    {
      type: notification_type,
      message: message,
      delivered: delivered,
      metadata: metadata
    }
  end

  # Generate comprehensive report
  def generate_report
    {
      type: notification_type,
      message: message,
      delivered: delivered,
      priority: priority
    }
  end
end
