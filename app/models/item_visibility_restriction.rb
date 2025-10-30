class ItemVisibilityRestriction < ApplicationRecord
  belongs_to :task
  belongs_to :coaching_relationship

  # ----------------------------
  # Soft deletion
  # ----------------------------
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

  # ----------------------------
  # Scopes
  # ----------------------------
  scope :for_task, ->(task) { where(task: task) }
  scope :for_coaching_relationship, ->(relationship) { where(coaching_relationship: relationship) }
  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  # ----------------------------
  # Validations
  # ----------------------------
  validates :task, uniqueness: { scope: :coaching_relationship_id }
  before_validation { self.active = true if active.nil? }
  validate :coaching_relationship_must_be_active
  validate :metadata_must_be_object

  # ----------------------------
  # State management
  # ----------------------------
  def active?
    !!active
  end

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end

  def inactive?
    !active?
  end

  def toggle!(value = nil)
    if value.nil?
      active? ? deactivate! : activate!
    else
      value ? activate! : deactivate!
    end
  end

  def visible?
    !active? # When restriction is active, the item is *hidden*; otherwise visible
  end

  # ----------------------------
  # Information methods
  # ----------------------------
  def summary
    {
      id: id,
      task_id: task_id,
      coaching_relationship_id: coaching_relationship_id,
      active: active
    }
  end

  def details
    {
      id: id,
      task_id: task_id,
      coaching_relationship_id: coaching_relationship_id,
      active: active,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  def age_hours
    return 0 unless created_at
    ((Time.current - created_at) / 1.hour).round(2)
  end

  def recent?(threshold_hours = 1)
    age_hours < threshold_hours
  end

  def priority
    active? ? "high" : "low"
  end

  def restriction_type
    "visibility"
  end

  def category
    "visibility"
  end

  def level
    active? ? "high" : "low"
  end

  def actionable?
    active?
  end

  def restriction_data
    {
      task_id: task_id,
      coaching_relationship_id: coaching_relationship_id,
      active: active
    }
  end

  def generate_report
    {
      restriction_type: restriction_type,
      active: active,
      task_id: task_id,
      coaching_relationship_id: coaching_relationship_id
    }
  end

  private

  def coaching_relationship_must_be_active
    return unless coaching_relationship
    if coaching_relationship.respond_to?(:status)
      errors.add(:coaching_relationship, "must be active") unless coaching_relationship.status.to_s == "active"
    elsif coaching_relationship.respond_to?(:active?)
      errors.add(:coaching_relationship, "must be active") unless coaching_relationship.active?
    end
  end

  def metadata_must_be_object
    return if metadata.nil?
    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a JSON object")
    end
  end
end
