# frozen_string_literal: true

class List < ApplicationRecord
  belongs_to :user
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy

  # Soft deletion
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

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

  # Soft delete
  def soft_delete!
    transaction do
      update!(deleted_at: Time.current)
      tasks.find_each { |t| t.update!(deleted_at: Time.current) }
    end
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Roles & permissions
  def role_for(user)
    return "owner" if self.user == user
    memberships.find_by(user: user)&.role
  end

  def can_edit?(user)
    role_for(user).in?(%w[owner editor])
  end

  def can_view?(user)
    role_for(user).present?
  end

  def accessible_by?(user)
    return false if user.nil?
    return false if deleted?
    user_id == user.id || memberships.exists?(user: user)
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