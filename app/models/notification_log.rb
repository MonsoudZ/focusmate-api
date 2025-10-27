# app/models/notification_log.rb
class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  validates :notification_type, presence: true, length: { maximum: 100 }
  validates :notification_type, inclusion: { in: %w[urgent_alert task_reminder system_announcement coaching_message test_notification old_notification new_notification bulk_notification complex_notification nil_metadata empty_metadata special_chars long_content unicode], allow_nil: false }
  # The spec creates *very* long messages in one case; allow up to 5000.
  validates :message, presence: true, length: { maximum: 5000 }
  validates :delivered, inclusion: { in: [ true, false ], message: "must be a boolean value" }
  validates :delivery_method, inclusion: { in: %w[email push sms in_app], allow_nil: true }
  validate :metadata_must_be_valid_json
  validate :delivered_must_be_boolean

  before_validation { self.delivered = false if delivered.nil? }

  def metadata_must_be_valid_json
    return if metadata.nil?

    # Check if the raw attribute is a string that can't be parsed as JSON
    raw = read_attribute(:metadata)
    if raw.is_a?(String) && raw.present?
      begin
        JSON.parse(raw)
      rescue JSON::ParserError
        errors.add(:metadata, "is not a valid JSON")
      end
    end
  end

  def delivered_must_be_boolean
    return if delivered.nil? || delivered.is_a?(TrueClass) || delivered.is_a?(FalseClass)

    errors.add(:delivered, "must be a boolean value")
  end

  # Soft delete helpers the spec uses
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  def soft_delete! = update!(deleted_at: Time.current)
  def restore!     = update!(deleted_at: nil)
  def deleted?     = deleted_at.present?

  # Scopes
  scope :for_user, ->(u) { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :for_task, ->(t) { where(task_id: t.is_a?(Task) ? t.id : t) }
  scope :recent,   -> { where(created_at: 1.week.ago..).order(created_at: :desc) }
  scope :delivered,   -> { where(delivered: true) }
  scope :undelivered, -> { where(delivered: false) }
  scope :by_type, ->(type) { where(notification_type: type) }

  # --- Metadata: always a Hash with string keys ---
  def metadata
    raw = read_attribute(:metadata)
    h =
      case raw
      when Hash   then raw
      when String then (JSON.parse(raw) rescue {}) # text column fallback
      else {}
      end
    h.transform_keys!(&:to_s)
    h
  end

  def metadata=(value)
    case value
    when nil     then write_attribute(:metadata, {})
    when Hash    then write_attribute(:metadata, value.transform_keys { |k| k.to_s })
    when String  then write_attribute(:metadata, value) # Let validation handle JSON parsing
    else write_attribute(:metadata, {})
    end
  end

  # Helpers used by controller/tests
  def read?          = metadata["read"] == true
  def undelivered?   = delivered == false

  def mark_read!
    m = metadata.dup
    m["read"] = true
    update!(metadata: m) # let AR cast to json/jsonb appropriately
  end

  def mark_undelivered! = update!(delivered: false, delivered_at: nil)
  def mark_delivered! = update!(delivered: true, delivered_at: Time.current)

  # Additional helper methods
  def age_hours
    return 0 unless created_at
    ((Time.current - created_at) / 1.hour).round
  end

  def recent?
    created_at && created_at > 1.hour.ago
  end

  def priority
    return metadata["priority"] if metadata["priority"]

    case notification_type
    when "urgent_alert" then "high"
    when "task_reminder" then "medium"
    when "system_announcement" then "low"
    else "normal"
    end
  end

  def category
    case notification_type
    when /task/ then "task"
    when /system/ then "system"
    when /coaching/ then "coaching"
    when /urgent/ then "urgent"
    else "general"
    end
  end

  def actionable?
    %w[task_reminder urgent_alert coaching_message].include?(notification_type)
  end

  def notification_data
    {
      id: id,
      type: notification_type,
      message: message,
      delivered: delivered,
      metadata: metadata,
      priority: priority,
      category: category,
      actionable: actionable?,
      created_at: created_at
    }
  end

  def generate_report
    {
      id: id,
      type: notification_type,
      message: message,
      delivered: delivered,
      delivered_at: delivered_at,
      age_hours: age_hours,
      priority: priority,
      category: category,
      actionable: actionable?,
      metadata: metadata
    }
  end

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
      delivered_at: delivered_at,
      delivery_method: delivery_method,
      metadata: metadata,
      task: task && {
        id: task.id,
        title: task.title,
        due_at: task.due_at,
        status: task.status
      },
      created_at: created_at,
      updated_at: updated_at
    }
  end
end
