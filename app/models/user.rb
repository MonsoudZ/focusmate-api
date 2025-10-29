class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Generate JTI on create and set default role
  before_create :generate_jti, :set_default_role

  # Validations
  validates :timezone, presence: true
  validates :role, presence: true, inclusion: { in: %w[client coach] }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true
  validate :valid_timezone

  # JWT token revocation
  def jwt_payload
    { "jti" => jti }
  end

  # Associations
  has_many :owned_lists, class_name: "List", foreign_key: "user_id", dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships, source: :list
  has_many :list_shares, dependent: :destroy
  has_many :shared_lists, through: :list_shares, source: :list
  has_many :devices, dependent: :destroy

  # NEW: Coaching associations
  has_many :coaching_relationships_as_coach, class_name: "CoachingRelationship", foreign_key: "coach_id", dependent: :destroy
  has_many :coaching_relationships_as_client, class_name: "CoachingRelationship", foreign_key: "client_id", dependent: :destroy
  has_many :clients, through: :coaching_relationships_as_coach, source: :client
  has_many :coaches, through: :coaching_relationships_as_client, source: :coach
  has_many :created_tasks, class_name: "Task", foreign_key: "creator_id", dependent: :destroy
  has_many :reviewed_tasks, class_name: "Task", foreign_key: "missed_reason_reviewed_by_id", dependent: :nullify
  has_many :saved_locations, dependent: :destroy
  has_many :user_locations, dependent: :destroy
  has_many :notification_logs, dependent: :destroy

  # NEW: Coaching-related methods

  # Check if user is a coach
  def coach?
    role == "coach"
  end

  # Check if user is a client
  def client?
    role == "client"
  end

  # Get all coaching relationships
  def all_coaching_relationships
    coaching_relationships_as_coach.or(coaching_relationships_as_client)
  end

  # Get active coaching relationships
  def active_coaching_relationships
    all_coaching_relationships.active
  end

  # Get all clients (if user is a coach)
  def all_clients
    clients.distinct
  end

  # Get all coaches (if user is a client)
  def all_coaches
    coaches.distinct
  end

  # Check if user has coaching relationship with another user
  def coaching_relationship_with?(other_user)
    all_coaching_relationships.exists?(coach: [ self, other_user ], client: [ self, other_user ])
  end

  # Get coaching relationship with another user
  def coaching_relationship_with(other_user)
    all_coaching_relationships.find_by(
      coach: [ self, other_user ],
      client: [ self, other_user ]
    )
  end

  # Get active coaching relationship with a specific coach
  def relationship_with_coach(coach)
    coaching_relationships_as_client.find_by(coach: coach, status: "active")
  end

  # Get active coaching relationship with a specific client
  def relationship_with_client(client)
    coaching_relationships_as_coach.find_by(client: client, status: "active")
  end

  # Get recent location
  def current_location
    user_locations.recent.first
  end

  # Get tasks requiring explanation
  def tasks_requiring_explanation
    all_lists = owned_lists + lists
    Task.joins(:list)
        .where(list: all_lists)
        .where(requires_explanation_if_missed: true)
        .where(status: :pending)
        .where("due_at < ?", Time.current)
  end

  # Get overdue tasks
  def overdue_tasks
    all_lists = owned_lists + lists
    Task.joins(:list)
        .where(list: all_lists)
        .where(status: :pending)
        .where("due_at < ?", Time.current)
  end


  # Get devices for push notifications
  def push_devices
    devices.where.not(apns_token: nil)
  end

  # Get unread notifications count
  def unread_notifications_count
    notification_logs.where("metadata->>'read' IS NULL OR metadata->>'read' = 'false'").count
  end

  # Update user's current location
  def update_location!(latitude, longitude, accuracy = nil)
    user_locations.create!(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      recorded_at: Time.current
    )
  end

  private

  def valid_timezone
    return if timezone.blank?

    begin
      Time.zone = timezone
      Time.zone
    rescue ArgumentError
      errors.add(:timezone, "is not a valid timezone")
    end
  end

  def set_default_role
    self.role = "client" if role.blank?
  end

  def generate_jti
    self.jti = SecureRandom.uuid
  end
end
