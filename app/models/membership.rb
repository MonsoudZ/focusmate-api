class Membership < ApplicationRecord
  belongs_to :list
  belongs_to :user
  belongs_to :coaching_relationship, optional: true

  validates :role, presence: true, inclusion: { in: %w[editor viewer] }
  validates :user_id, uniqueness: { scope: :list_id, message: "is already a member of this list" }

  # Scopes
  scope :editors, -> { where(role: "editor") }
  scope :viewers, -> { where(role: "viewer") }

  # Check if user can perform actions
  def can_edit?
    role == "editor"
  end

  def can_invite?
    role == "editor"
  end

  # Determine if this is a coach membership
  def coach_membership?
    coaching_relationship_id.present?
  end

  # Check if this membership receives overdue alerts
  def receives_overdue_alerts?
    receive_overdue_alerts
  end

  # Check if this membership can add items
  def can_add_items?
    can_add_items
  end
end
