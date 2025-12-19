class List < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy

  # Soft deletion
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete!
    transaction do
      update!(deleted_at: Time.current)
      tasks.find_each do |t|
        if t.respond_to?(:soft_delete!)
          t.soft_delete!
        else
          t.update!(deleted_at: Time.current)
        end
      end
    end
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Validations
  validates :user, presence: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }, allow_nil: true

  VISIBILITIES = %w[public private shared].freeze
  validates :visibility, inclusion: { in: VISIBILITIES }

  before_validation do
    self.visibility ||= "private"
  end

  # Scopes
  scope :owned_by, ->(user) { where(user: user) }
  scope :accessible_by, ->(user) { left_joins(:memberships).where(memberships: { user: user }).or(where(user: user)) }
  scope :modified_since, ->(ts) { where("updated_at > ? OR deleted_at > ?", ts, ts) }
  scope :publicly_visible, -> { where(visibility: "public") }
  scope :privately_visible, -> { where(visibility: "private") }
  scope :shared_visible, -> { where(visibility: "shared") }

  # Visibility scopes (using send to avoid naming conflict with Ruby keyword)
  scope :public_records, -> { where(visibility: "public") }
  scope :private_records, -> { where(visibility: "private") }
  scope :shared, -> { where(visibility: "shared") }

  class << self
    alias_method :public, :public_records
    alias_method :private, :private_records
  end

  # Roles & permissions
  def role_for(user)
    return "owner" if self.user == user
    memberships.find_by(user: user)&.role
  end

  def can_edit?(user)
    role_for(user).in?(%w[owner editor])
  end
  alias_method :editable_by?, :can_edit?
  alias_method :can_add_items_by?, :can_edit?
  alias_method :can_delete_items_by?, :can_edit?

  def can_view?(user)
    role_for(user).present?
  end

  # Membership helpers
  def add_member!(user, role = "viewer")
    memberships.create!(user: user, role: role)
  end

  def remove_member!(user)
    memberships.find_by(user: user)&.destroy
  end

  def member?(user)
    memberships.exists?(user: user)
  end

  # Task statistics and activity methods
  def task_count
    tasks.count
  end

  def completed_task_count
    tasks.where(status: :done).count
  end

  def completion_rate
    return 0.0 if task_count.zero?
    (completed_task_count.to_f / task_count * 100).round(2)
  end

  def overdue_task_count
    tasks.where(status: :pending).where("due_at < ?", Time.current).count
  end

  def recent_activity(limit = 10)
    tasks.order(created_at: :desc).limit(limit)
  end

  def summary
    {
      id: id,
      name: name,
      description: description,
      task_count: task_count,
      completed_task_count: completed_task_count,
      completion_rate: completion_rate
    }
  end

  def statistics
    total = task_count
    completed = completed_task_count
    pending = tasks.where(status: :pending).count
    overdue = overdue_task_count

    {
      total_tasks: total,
      completed_tasks: completed,
      pending_tasks: pending,
      overdue_tasks: overdue,
      completion_rate: total.zero? ? 0.0 : (completed.to_f / total * 100).round(2)
    }
  end

  # Access checks
  def accessible_by?(user)
    return false if user.nil?
    return false if deleted?
    return true if user_id == user.id
    return true if memberships.where(user: user).exists?
    false
  end
end
