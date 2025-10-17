class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Generate JTI on create
  before_create :generate_jti

  # JWT token revocation
  def jwt_payload
    { 'jti' => jti }
  end

  # Associations
  has_many :owned_lists, class_name: 'List', foreign_key: 'user_id', dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :lists, through: :memberships, source: :list
  has_many :list_shares, dependent: :destroy
  has_many :shared_lists, through: :list_shares, source: :list
  has_many :devices, dependent: :destroy
  
  # NEW: Coaching associations
  has_many :coaching_relationships_as_coach, class_name: 'CoachingRelationship', foreign_key: 'coach_id', dependent: :destroy
  has_many :coaching_relationships_as_client, class_name: 'CoachingRelationship', foreign_key: 'client_id', dependent: :destroy
  has_many :clients, through: :coaching_relationships_as_coach, source: :client
  has_many :coaches, through: :coaching_relationships_as_client, source: :coach
  has_many :created_tasks, class_name: 'Task', foreign_key: 'creator_id', dependent: :destroy
  has_many :reviewed_tasks, class_name: 'Task', foreign_key: 'missed_reason_reviewed_by_id', dependent: :nullify
  has_many :saved_locations, dependent: :destroy
  has_many :user_locations, dependent: :destroy
  has_many :notification_logs, dependent: :destroy

  # NEW: Coaching-related methods
  
  # Check if user is a coach
  def coach?
    role == 'coach'
  end
  
  # Check if user is a client
  def client?
    role == 'client'
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
    all_coaching_relationships.exists?(coach: [self, other_user], client: [self, other_user])
  end
  
  # Get coaching relationship with another user
  def coaching_relationship_with(other_user)
    all_coaching_relationships.find_by(
      coach: [self, other_user], 
      client: [self, other_user]
    )
  end

  # Get active coaching relationship with a specific coach
  def relationship_with_coach(coach)
    coaching_relationships_as_client.find_by(coach: coach, status: 'active')
  end

  # Get active coaching relationship with a specific client
  def relationship_with_client(client)
    coaching_relationships_as_coach.find_by(client: client, status: 'active')
  end
  
  # Get recent location
  def current_location
    user_locations.recent.first
  end
  
  # Get location history for a time period
  def location_history(start_time, end_time)
    user_locations.within_timeframe(start_time, end_time).recent
  end
  
  # Check if user is at a specific location
  def at_location?(latitude, longitude, radius = 100)
    return false unless current_location
    
    current_location.distance_to(latitude, longitude) <= radius
  end
  
  # Get tasks requiring explanation
  def tasks_requiring_explanation
    Task.joins(:list)
        .where(list: lists)
        .where(requires_explanation_if_missed: true)
        .where(status: :pending)
        .where('due_at < ?', Time.current)
  end
  
  # Get overdue tasks
  def overdue_tasks
    Task.joins(:list)
        .where(list: lists)
        .where(status: :pending)
        .where('due_at < ?', Time.current)
  end

  # Get lists shared with this coach
  def shared_lists
    List.joins(:memberships)
        .where(memberships: { user: self })
        .where.not(memberships: { coaching_relationship_id: nil })
  end

  # Get lists owned by this user that are shared with coaches
  def lists_shared_with_coaches
    owned_lists.joins(:memberships)
               .where.not(memberships: { coaching_relationship_id: nil })
               .distinct
  end

  # Get devices for push notifications
  def push_devices
    devices.where.not(apns_token: nil)
  end

  # Get iOS devices
  def ios_devices
    devices.ios
  end

  # Get Android devices
  def android_devices
    devices.android
  end

  # Check if user has any registered devices
  def has_devices?
    devices.exists?
  end

  # Get device count
  def device_count
    devices.count
  end

  # Get unread notifications count
  def unread_notifications_count
    notification_logs.where("metadata->>'read' IS NULL OR metadata->>'read' = 'false'").count
  end

  # Get recent notifications
  def recent_notifications(limit = 10)
    notification_logs.recent.limit(limit)
  end

  # Get notifications by type
  def notifications_by_type(type)
    notification_logs.by_type(type)
  end

  # Mark all notifications as read
  def mark_all_notifications_read!
    notification_logs.update_all(
      metadata: notification_logs.pluck(:metadata).map do |meta|
        parsed = JSON.parse(meta) rescue {}
        parsed.merge('read' => true).to_json
      end
    )
  end

  # Get notification statistics
  def notification_stats
    {
      total: notification_logs.count,
      unread: unread_notifications_count,
      delivered: notification_logs.delivered.count,
      undelivered: notification_logs.undelivered.count,
      recent: notification_logs.recent.count
    }
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

  # Get location history for a specific time period
  def location_history(start_time = 1.week.ago, end_time = Time.current)
    user_locations.where(recorded_at: start_time..end_time).order(:recorded_at)
  end

  # Check if user is at a specific saved location
  def at_location?(saved_location, current_latitude = nil, current_longitude = nil)
    return false unless current_latitude && current_longitude
    
    # Use current location if not provided
    current_lat = current_latitude || current_location&.latitude
    current_lng = current_longitude || current_location&.longitude
    
    return false unless current_lat && current_lng
    
    # Calculate distance using Haversine formula
    distance = calculate_distance(
      current_lat, current_lng,
      saved_location.latitude, saved_location.longitude
    )
    
    distance <= saved_location.radius_meters
  end

  private

  # Calculate distance between two points using Haversine formula
  def calculate_distance(lat1, lon1, lat2, lon2)
    # Earth's radius in meters
    earth_radius = 6_371_000
    
    # Convert degrees to radians
    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180
    
    # Haversine formula
    a = Math.sin(delta_lat / 2) ** 2 + 
        Math.cos(lat1_rad) * Math.cos(lat2_rad) * 
        Math.sin(delta_lon / 2) ** 2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    
    earth_radius * c
  end

  def generate_jti
    self.jti = SecureRandom.uuid
  end
end
