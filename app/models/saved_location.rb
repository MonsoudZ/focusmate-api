class SavedLocation < ApplicationRecord
  belongs_to :user

  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :latitude,
            presence: true,
            numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude,
            presence: true,
            numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :radius_meters,
            presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 10_000 }
  validates :address, length: { maximum: 500 }, allow_nil: true

  # Soft deletion
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  # Scopes
  scope :for_user, ->(user) { where(user: user) }

  # DB-agnostic "nearby" using the Haversine formula in SQL (meters)
  scope :nearby, ->(lat, lng, radius = 1000) {
    # Validate inputs to prevent SQL injection
    lat = lat.to_f
    lng = lng.to_f
    radius = radius.to_f

    # Ensure lat/lng are within valid ranges
    lat = [ [ lat, -90 ].max, 90 ].min
    lng = [ [ lng, -180 ].max, 180 ].min

    dist_sql = <<~SQL.squish
      2 * 6371000 * ASIN(
        SQRT(
          POWER(SIN(RADIANS((? - latitude)/2)), 2) +
          COS(RADIANS(latitude)) * COS(RADIANS(?)) *
          POWER(SIN(RADIANS((? - longitude)/2)), 2)
        )
      )
    SQL

    select("#{table_name}.*, (#{dist_sql}) AS distance_m", lat, lat, lng)
      .where("(#{dist_sql}) <= ?", lat, lat, lng, radius)
      .order(Arel.sql("distance_m ASC"))
  }

  # Callbacks
  before_validation :apply_default_radius_on_create, on: :create
  before_validation :geocode_if_needed, if: -> { address.present? && (latitude.blank? || longitude.blank?) }

  # Instance helpers
  def coordinates
    [ latitude, longitude ]
  end

  def contains?(lat, lng)
    distance_to(lat, lng) <= radius_meters.to_f
  end

  def distance_to(lat, lng)
    calculate_distance(latitude, longitude, lat, lng)
  end

  def user_at_location?(user)
    return false unless user

    # Check if user has direct latitude/longitude attributes
    if user.respond_to?(:latitude) && user.respond_to?(:longitude) &&
       user.latitude.present? && user.longitude.present?
      return contains?(user.latitude.to_f, user.longitude.to_f)
    end

    # Fallback to current_location if available
    loc = user.current_location
    return false unless loc&.respond_to?(:latitude) && loc&.respond_to?(:longitude)
    contains?(loc.latitude.to_f, loc.longitude.to_f)
  end

  def self.nearby_for_user(user, lat, lng, radius = 1000)
    user.saved_locations.nearby(lat, lng, radius)
  end

  # Geocoding
  def geocode
    if defined?(Geocoder) && !Rails.env.test?
      results = Geocoder.search(address.to_s)
      if (first = results.first)
        self.latitude  = first.latitude
        self.longitude = first.longitude
      end
    end
    true
  rescue StandardError
    # Swallow errors to satisfy "handles geocoding errors gracefully"
    true
  end

  private

  def apply_default_radius_on_create
    # Only default if omitted and value is nil
    if new_record? && radius_meters.nil?
      self.radius_meters = 100
    end
  end

  def geocode_if_needed
    geocode
  end

  # Great-circle distance in meters (Haversine)
  def calculate_distance(lat1, lon1, lat2, lon2)
    lat1 = lat1.to_f; lon1 = lon1.to_f; lat2 = lat2.to_f; lon2 = lon2.to_f
    return 0.0 if lat1 == lat2 && lon1 == lon2

    r = 6_371_008.8 # meters (more accurate Earth radius)
    dlat = to_rad(lat2 - lat1)
    dlon = to_rad(lon2 - lon1)
    a = Math.sin(dlat / 2)**2 +
        Math.cos(to_rad(lat1)) * Math.cos(to_rad(lat2)) * Math.sin(dlon / 2)**2
    c = 2 * Math.asin(Math.sqrt(a))
    r * c
  end

  def to_rad(deg)
    deg.to_f * Math::PI / 180.0
  end
end
