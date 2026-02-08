# frozen_string_literal: true

class List < ApplicationRecord
  include SoftDeletable
  belongs_to :user
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy
  has_many :invites, class_name: "ListInvite", dependent: :destroy

  # Validations
  validates :user, presence: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }, allow_nil: true

  VISIBILITIES = %w[public private shared].freeze
  validates :visibility, inclusion: { in: VISIBILITIES }

  COLORS = %w[blue green orange red purple pink teal yellow gray].freeze
  validates :color, inclusion: { in: COLORS }, allow_nil: true

  before_validation do
    self.visibility ||= "private"
    self.color ||= "blue"
  end

  # Scopes
  scope :owned_by, ->(user) { where(user: user) }
  scope :accessible_by, ->(user) { left_joins(:memberships).where(memberships: { user: user }).or(where(user: user)) }
  scope :modified_since, ->(ts) { where("updated_at > ? OR deleted_at > ?", ts, ts) }

  # Override soft_delete! to cascade to tasks with correct counter adjustments.
  # tasks.update_all bypasses Task callbacks that maintain counter caches,
  # so we adjust them atomically here.
  def soft_delete!
    transaction do
      active_tasks = tasks.where(deleted_at: nil)
      total_count = active_tasks.count
      parent_count = active_tasks.where(parent_task_id: nil).count

      # Collect parent tasks whose subtasks_count needs adjusting
      subtask_counts_by_parent = active_tasks
        .where.not(parent_task_id: nil)
        .group(:parent_task_id)
        .count

      super
      tasks.with_deleted.where(deleted_at: nil).update_all(deleted_at: deleted_at)

      # Adjust list counter caches (use with_deleted since list is now soft-deleted)
      if total_count > 0
        List.with_deleted.where(id: id).update_all(
          "tasks_count = GREATEST(tasks_count - #{total_count}, 0), " \
          "parent_tasks_count = GREATEST(parent_tasks_count - #{parent_count}, 0)"
        )
      end

      # Adjust subtasks_count on parent tasks (use with_deleted since tasks are now soft-deleted)
      subtask_counts_by_parent.each do |parent_id, count|
        Task.with_deleted.where(id: parent_id).update_all(
          "subtasks_count = GREATEST(subtasks_count - #{count}, 0)"
        )
      end
    end
  end

  # Override restore! to also restore tasks that were cascade-deleted
  # alongside this list. Cascade-deleted tasks share the exact same
  # deleted_at timestamp as the list (set by update_all in soft_delete!).
  def restore!
    cascade_deleted_at = deleted_at
    return super unless cascade_deleted_at

    transaction do
      cascade_tasks = tasks.with_deleted.where(deleted_at: cascade_deleted_at)

      total_count = cascade_tasks.count
      parent_count = cascade_tasks.where(parent_task_id: nil).count
      subtask_counts_by_parent = cascade_tasks
        .where.not(parent_task_id: nil)
        .group(:parent_task_id)
        .count

      cascade_tasks.update_all(deleted_at: nil)
      super

      # Re-increment list counter caches
      if total_count > 0
        List.where(id: id).update_all(
          "tasks_count = tasks_count + #{total_count}, " \
          "parent_tasks_count = parent_tasks_count + #{parent_count}"
        )
      end

      # Re-increment subtasks_count on parent tasks
      subtask_counts_by_parent.each do |parent_id, count|
        Task.where(id: parent_id).update_all(
          "subtasks_count = subtasks_count + #{count}"
        )
      end
    end
  end

  # Roles & permissions - delegates to Permissions::ListPermissions
  # for centralized permission logic
  def role_for(user)
    Permissions::ListPermissions.role_for(self, user)
  end

  def can_edit?(user)
    Permissions::ListPermissions.can_edit?(self, user)
  end

  def can_view?(user)
    Permissions::ListPermissions.can_view?(self, user)
  end

  def accessible_by?(user)
    Permissions::ListPermissions.accessible?(self, user)
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
end
