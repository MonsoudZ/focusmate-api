# app/models/notification_log.rb
class NotificationLog < ApplicationRecord
  belongs_to :user
  belongs_to :task, optional: true

  # --- Constants ---
  NOTIFICATION_TYPES = %w[
    task_reminder task_due_soon task_overdue task_escalated
    system_announcement coaching_message urgent_alert
  ].freeze

  DELIVERY_METHODS = %w[email push sms in_app].freeze

  # --- Soft delete default scope ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  # --- Scopes ---
  scope :delivered,    -> { where(delivered: true) }
  scope :undelivered,  -> { where(delivered: false) }
  scope :by_type,      ->(type) { where(notification_type: type) }
  scope :recent,       -> { where("created_at > ?", 7.days.ago).order(created_at: :desc) }
  scope :for_user,     ->(u) { where(user: u) }
  scope :for_task,     ->(t) { where(task: t) }

  # JSON column that always yields a Hash
  attribute :metadata, :json, default: {}

  # --- Validations ---
  validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES }
  validates :message,           presence: true, length: { maximum: 1000 }
  validates :delivered,         inclusion: { in: [ true, false ], message: "must be a boolean value" }
  validate  :delivered_must_be_boolean
  validates :delivery_method,   inclusion: { in: DELIVERY_METHODS }, allow_nil: true
  validate  :metadata_is_hash

  # --- Callbacks ---
  before_validation :set_default_delivered, if: -> { delivered.nil? }

  # --- Delivery helpers ---
  def delivered? = delivered
  def undelivered? = !delivered?

  def mark_delivered!
    update!(delivered: true, delivered_at: Time.current)
  end

  def mark_undelivered!
    update!(delivered: false, delivered_at: nil)
  end

  # Mirror delivery_method into metadata["channel"] for tracking
  def delivery_method=(val)
    super(val)
    self.metadata ||= {}
    self.metadata["channel"] = val if val.present?
  end

  # Track original delivered value for validation
  def delivered=(val)
    @original_delivered_value = val
    super(val)
  end

  # --- JSON helpers ---
  def metadata_is_hash
    return if metadata.nil?
    errors.add(:metadata, "is not a valid JSON") unless metadata.is_a?(Hash)
  end

  def delivered_must_be_boolean
    return if delivered.nil?
    # Check if the original value was a string (Rails converts truthy strings to true)
    if @original_delivered_value.is_a?(String) && @original_delivered_value != "true" && @original_delivered_value != "false"
      errors.add(:delivered, "must be a boolean value")
    end
  end

  # --- Derived flags/summary ---
  def read?
    metadata["read"] == true
  end

  def mark_read!
    self.metadata ||= {}
    self.metadata["read"] = true
    save!
  end

  def age_hours
    return 0.0 unless created_at
    ((Time.current - created_at) / 1.hour).round(1)
  end

  def recent?
    created_at.present? && created_at > 1.hour.ago
  end

  def priority
    case notification_type
    when "task_overdue", "task_escalated", "urgent_alert"
      "high"
    when "task_due_soon", "coaching_message", "task_reminder"
      "medium"
    else
      "low"
    end
  end

  def category
    case notification_type
    when /\Atask_/
      "task"
    when /\Acoaching_/
      "coaching"
    when "system_announcement"
      "system"
    else
      "general"
    end
  end

  def actionable?
    %w[task_due_soon task_overdue urgent_alert coaching_message task_reminder].include?(notification_type)
  end

  def summary
    {
      id: id,
      notification_type: notification_type,
      message: message,
      delivered: delivered,
      metadata: metadata,
      read: read?,
      created_at: created_at
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
      read: read?,
      task: task ? { id: task.id, title: task.title, due_at: task.due_at, status: task.status } : nil,
      metadata: metadata,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def notification_data
    {
      user_id: user_id,
      task_id: task_id,
      type: notification_type,
      message: message,
      delivered: delivered,
      delivery_method: delivery_method,
      metadata: metadata
    }
  end

  def generate_report
    {
      type: notification_type,
      message: message,
      delivered: delivered,
      priority: priority,
      category: category,
      channel: delivery_method || metadata["channel"] || "n/a",
      created_at: created_at&.iso8601,
      user_id: user_id,
      task_id: task_id
    }
  end

  # --- Soft delete helpers ---
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  private

  def set_default_delivered
    self.delivered = false
  end
end
