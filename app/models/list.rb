class List < ApplicationRecord
  # Associations
  belongs_to :user
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy
  has_many :list_shares, dependent: :destroy
  has_many :shared_users, through: :list_shares, source: :user

  # Coaching links
  has_many :coaching_memberships, -> { where.not(coaching_relationship_id: nil) }, class_name: "Membership"
  has_many :coaching_relationships, through: :coaching_memberships
  has_many :coaches, through: :coaching_relationships, source: :coach

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

  def can_invite?(user)
    role_for(user).in?(%w[owner editor])
  end

  def can_add_items?(user)
    role_for(user).in?(%w[owner editor])
  end

  def viewable_by?(user)
    can_view?(user) || list_shares.exists?(user: user)
  end

  def editable_by?(user)
    return true if self.user == user
    return true if can_edit?(user)
    share = list_shares.find_by(user: user)
    share&.can_edit? || false
  end

  def can_add_items_by?(user)
    return true if self.user == user
    return true if can_add_items?(user)
    list_shares.find_by(user: user)&.can_add_items? || false
  end

  def can_delete_items_by?(user)
    return true if self.user == user
    return true if can_edit?(user)
    list_shares.find_by(user: user)&.can_delete_items? || false
  end

  # Sharing helpers
  def share_with!(user, permissions = {})
    list_shares.create!(
      user: user,
      email: user.email,
      role: (permissions[:role] || "viewer"),
      status: "accepted",
      can_view: permissions.fetch(:can_view, true),
      can_edit: permissions.fetch(:can_edit, false),
      can_add_items: permissions.fetch(:can_add_items, false),
      can_delete_items: permissions.fetch(:can_delete_items, false),
      receive_notifications: permissions.fetch(:receive_notifications, true)
    )
  end

  def invite_by_email!(email, role = "viewer", permissions = {})
    list_shares.create!(
      email: email,
      role: role,
      status: "pending",
      can_view: permissions.fetch(:can_view, true),
      can_edit: permissions.fetch(:can_edit, false),
      can_add_items: permissions.fetch(:can_add_items, false),
      can_delete_items: permissions.fetch(:can_delete_items, false),
      receive_notifications: permissions.fetch(:receive_notifications, true)
    )
  end

  def unshare_with!(user)
    list_shares.find_by(user: user)&.destroy
  end

  def shared_with?(user)
    list_shares.exists?(user: user)
  end

  def share_permissions_for(user)
    list_shares.find_by(user: user)&.permissions_hash || {}
  end

  def update_share_permissions!(user, permissions)
    list_shares.find_by(user: user)&.update_permissions(permissions)
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

  # Access checks
  def accessible_by?(user)
    return false if user.nil?
    return false if deleted?
    return true if user_id == user.id
    return true if list_shares.where(user: user, status: "accepted").exists?
    return true if memberships.where(user: user).exists?
    false
  end

  # Coaching helpers
  def coach?(user)
    coaches.include?(user) ||
      memberships.exists?(user: user, role: "coach") ||
      list_shares.exists?(user: user, role: "coach", status: "accepted") ||
      user.role == "coach"
  end

  def all_coaches
    coaches.distinct
  end

  def has_coaching?
    coaching_relationships.exists?
  end
end
