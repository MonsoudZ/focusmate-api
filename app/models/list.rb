# frozen_string_literal: true

class List < ApplicationRecord
  include SoftDeletable
  include Colorable
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

  before_validation do
    self.visibility ||= "private"
    self.color ||= "blue"
  end

  # Scopes
  scope :owned_by, ->(user) { where(user: user) }
  scope :accessible_by, ->(user) { left_joins(:memberships).where(memberships: { user: user }).or(where(user: user)) }
  scope :modified_since, ->(ts) { where("updated_at > ? OR deleted_at > ?", ts, ts) }

  # Override soft_delete! to cascade to tasks
  def soft_delete!
    transaction do
      super
      # Bulk update all tasks in one query instead of N individual updates
      tasks.update_all(deleted_at: Time.current)
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
