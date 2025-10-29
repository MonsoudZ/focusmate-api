class CoachingRelationship < ApplicationRecord
  enum :status, { pending: "pending", active: "active", inactive: "inactive", declined: "declined" }

  belongs_to :coach, class_name: "User"
  belongs_to :client, class_name: "User"
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships
  has_many :daily_summaries, dependent: :destroy
  has_many :item_visibility_restrictions, dependent: :destroy

  validates :coach_id, :client_id, presence: true
  validates :status, presence: true
  validates :client_id, uniqueness: { scope: :coach_id }
  validate :coach_and_client_different

  scope :between, ->(coach_id:, client_id:) { where(coach_id:, client_id:) }

  # Scopes for status filtering
  scope :active, -> { where(status: "active") }
  scope :pending, -> { where(status: "pending") }
  scope :inactive, -> { where(status: "inactive") }
  scope :declined, -> { where(status: "declined") }
  scope :for_user, ->(user_id) { where("coach_id = ? OR client_id = ?", user_id, user_id) }

  # Instance methods
  def active?
    status == "active"
  end

  def pending?
    status == "pending"
  end

  def inactive?
    status == "inactive"
  end

  def declined?
    status == "declined"
  end

  def activate!
    update!(status: "active")
  end

  def deactivate!
    update!(status: "inactive")
  end

  def decline!
    update!(status: "declined")
  end

  def user_role(user)
    return "coach" if coach_id == user.id
    return "client" if client_id == user.id
    nil
  end

  def other_user(user)
    return coach if client_id == user.id
    return client if coach_id == user.id
    nil
  end

  def can_be_accessed_by?(user)
    coach_id == user.id || client_id == user.id
  end

  def can_be_modified_by?(user)
    # Only coach can modify the relationship
    coach_id == user.id
  end

  def display_name_for(user)
    other_user = other_user(user)
    return "Unknown" unless other_user

    other_user.name.presence || other_user.email
  end

  # Class methods
  class << self
    def find_between(coach_id:, client_id:)
      between(coach_id: coach_id, client_id: client_id).first
    end

    def find_or_create_between(coach_id:, client_id:, status: "pending")
      find_between(coach_id: coach_id, client_id: client_id) ||
        create!(coach_id: coach_id, client_id: client_id, status: status)
    end

    def active_for_user(user_id)
      for_user(user_id).active
    end

    def pending_for_user(user_id)
      for_user(user_id).pending
    end

    def count_by_status
      group(:status).count
    end

    def recent(limit = 10)
      order(created_at: :desc).limit(limit)
    end
  end

  private

  def coach_and_client_different
    errors.add(:client_id, "cannot be the same as coach") if coach_id == client_id
  end
end
