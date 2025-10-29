class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  validates :notification_type, presence: true, length: { maximum: 100 }
  validates :notification_type, inclusion: { in: %w[urgent_alert task_reminder system_announcement coaching_message test_notification old_notification new_notification bulk_notification complex_notification nil_metadata empty_metadata special_chars long_content unicode], allow_nil: false }
  validates :message, presence: true, length: { maximum: 5000 }
  validates :delivered, inclusion: { in: [ true, false ], message: "must be a boolean value" }
  validates :delivery_method, inclusion: { in: %w[email push sms in_app], allow_nil: true }

  before_validation { self.delivered = false if delivered.nil? }

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
end
