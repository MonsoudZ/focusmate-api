class List < ApplicationRecord
  belongs_to :owner, class_name: "User", foreign_key: "user_id"
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  has_many :tasks, dependent: :destroy
  has_many :list_shares, dependent: :destroy
  has_many :shared_users, through: :list_shares, source: :user

  # NEW: Coaching-specific memberships
  has_many :coaching_memberships, -> { where.not(coaching_relationship_id: nil) },
           class_name: "Membership"
  has_many :coaching_relationships, through: :coaching_memberships
  has_many :coaches, through: :coaching_relationships, source: :coach

  validates :name, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 1000 }

  # Scopes
  scope :owned_by, ->(user) { where(owner: user) }
  scope :accessible_by, ->(user) {
    left_joins(:memberships)
      .where(memberships: { user: user })
      .or(where(owner: user))
  }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :modified_since, ->(timestamp) { where("updated_at > ? OR deleted_at > ?", timestamp, timestamp) }

  # Check if user has specific role
  def role_for(user)
    return "owner" if owner == user
    membership = memberships.find_by(user: user)
    membership&.role
  end

  # Check permissions
  def can_edit?(user)
    role_for(user).in?([ "owner", "editor" ])
  end

  def can_view?(user)
    role_for(user).present?
  end

  def can_invite?(user)
    role_for(user).in?([ "owner", "editor" ])
  end

  def can_add_items?(user)
    role_for(user).in?([ "owner", "editor" ])
  end

  def viewable_by?(user)
    # Check if user is owner, member, or has a share
    role_for(user).present? || list_shares.exists?(user: user)
  end

  def editable_by?(user)
    # Owner can always edit
    return true if owner == user

    # Check membership permissions
    role = role_for(user)
    return true if role.in?([ "owner", "editor" ])

    # Check share permissions
    share = list_shares.find_by(user: user)
    return share&.can_edit? if share

    false
  end

  def can_add_items_by?(user)
    # Owner can always add items
    return true if owner == user

    # Check membership permissions
    role = role_for(user)
    return true if role.in?([ "owner", "editor" ])

    # Check share permissions
    share = list_shares.find_by(user: user)
    return share&.can_add_items? if share

    false
  end

  def can_delete_items_by?(user)
    # Owner can always delete items
    return true if owner == user

    # Check membership permissions
    role = role_for(user)
    return true if role.in?([ "owner", "editor" ])

    # Check share permissions
    share = list_shares.find_by(user: user)
    return share&.can_delete_items? if share

    false
  end

  # Sharing methods
  def share_with!(user, permissions = {})
    list_shares.create!(
      user: user,
      email: user.email,
      role: permissions[:role] || "viewer",
      status: "accepted",
      can_view: permissions[:can_view] != false,
      can_edit: permissions[:can_edit] || false,
      can_add_items: permissions[:can_add_items] || false,
      can_delete_items: permissions[:can_delete_items] || false,
      receive_notifications: permissions[:receive_notifications] != false
    )
  end

  def invite_by_email!(email, role = "viewer", permissions = {})
    list_shares.create!(
      email: email,
      role: role,
      can_view: permissions[:can_view] != false,
      can_edit: permissions[:can_edit] || false,
      can_add_items: permissions[:can_add_items] || false,
      can_delete_items: permissions[:can_delete_items] || false,
      receive_notifications: permissions[:receive_notifications] != false
    )
  end

  def unshare_with!(user)
    list_shares.find_by(user: user)&.destroy
  end

  def shared_with?(user)
    list_shares.exists?(user: user)
  end

  def share_permissions_for(user)
    share = list_shares.find_by(user: user)
    share&.permissions_hash || {}
  end

  def update_share_permissions!(user, permissions)
    share = list_shares.find_by(user: user)
    share&.update_permissions(permissions)
  end

  # Check if user has access to this list
  def accessible_by?(user)
    return true if user_id == user.id
    list_shares.exists?(user_id: user.id, status: "accepted")
  end

  # Get user's role for this list
  def role_for(user)
    return "owner" if user_id == user.id
    list_shares.find_by(user_id: user.id, status: "accepted")&.role || "none"
  end

  # Get list share for user
  def share_for(user)
    list_shares.find_by(user_id: user.id)
  end

  # Get pending invitations
  def pending_invitations
    list_shares.where(status: "pending")
  end

  # Get accepted shares
  def accepted_shares
    list_shares.where(status: "accepted")
  end

  # NEW: Coaching-related methods

  # Check if user is a coach for this list
  def coach?(user)
    coaches.include?(user)
  end

  # Get all coaches for this list
  def all_coaches
    coaches.distinct
  end

  # Check if list has coaching relationships
  def has_coaching?
    coaching_relationships.exists?
  end

  # Get tasks visible to a specific coaching relationship
  def tasks_for_coaching_relationship(coaching_relationship)
    tasks.left_joins(:visibility_restrictions)
         .where(
           visibility_restrictions: { coaching_relationship: coaching_relationship }
         )
         .or(tasks.where(visibility_restrictions: { id: nil }))
  end

  # Get overdue tasks for coaching alerts
  def overdue_tasks
    tasks.joins(:escalation)
         .where(status: :pending)
         .where("due_at < ?", Time.current)
  end

  # Get tasks requiring explanation
  def tasks_requiring_explanation
    tasks.where(requires_explanation_if_missed: true)
         .where(status: :pending)
         .where("due_at < ?", Time.current)
  end

  # Get location-based tasks
  def location_based_tasks
    tasks.where(location_based: true)
  end

  # Get recurring tasks
  def recurring_tasks
    tasks.where(is_recurring: true)
  end

  # Get lists shared with a specific coach
  def self.shared_with_coach(coach)
    joins(:memberships)
      .where(memberships: { user: coach })
      .where.not(memberships: { coaching_relationship_id: nil })
  end

  # Check if list is shared with a specific coach
  def shared_with_coach?(coach)
    memberships.exists?(user: coach, coaching_relationship_id: coaching_relationships)
  end

  # Get all coaches this list is shared with
  def shared_coaches
    User.joins(:memberships)
        .where(memberships: { list: self })
        .where.not(memberships: { coaching_relationship_id: nil })
        .distinct
  end

  # Get tasks visible to a specific user
  def tasks_visible_to(user)
    if owner == user
      # Owner can see all tasks
      tasks
    elsif user.coach? && shared_with?(user)
      # Coach can see tasks based on visibility restrictions
      tasks.left_joins(:visibility_restrictions)
           .where(
             visibility_restrictions: { id: nil }
           ).or(
             tasks.joins(:visibility_restrictions)
                  .where(visibility_restrictions: { coaching_relationship: user.coaching_relationships_as_coach })
           )
    else
      # Regular member can see all tasks
      tasks
    end
  end

  # Check if list is shared with a specific user
  def shared_with?(user)
    return false unless user.coach?

    memberships.exists?(user: user, coaching_relationship_id: coaching_relationships)
  end

  # Soft delete methods
  def deleted?
    deleted_at.present?
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  # Override destroy to use soft delete
  def destroy
    soft_delete!
  end

  # Override delete to use soft delete
  def delete
    soft_delete!
  end
end
