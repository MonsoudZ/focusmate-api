class UserLocation < ApplicationRecord
  # ----- Constants -----
  SOURCES = %w[gps network passive].freeze
  ACCURACY_THRESHOLDS = { high: 10, medium: 50, low: 100 }.freeze
  RECENT_WINDOW = 1.hour + 1.minute

  # ----- Associations -----
  belongs_to :user

  # ----- Soft delete -----
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete! = update!(deleted_at: Time.current)
  def restore!     = update!(deleted_at: nil)
  def deleted?     = deleted_at.present?

  # ----- Validations -----
  validates :latitude,  presence: true,
                        numericality: { greater_than_or_equal_to: -90,  less_than_or_equal_to: 90 }
  validates :longitude, presence: true,
                        numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :recorded_at, presence: true

  validates :accuracy,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1000 },
            allow_nil: true

  validates :source,
            inclusion: { in: SOURCES },
            allow_nil: true

  # ----- Callbacks -----
  before_validation :ensure_recorded_at_and_source

  # ----- Scopes -----
  scope :for_user,  ->(u) { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :recent,    -> { where('recorded_at >= ?', RECENT_WINDOW.ago) }
  scope :accurate,  -> { where('accuracy IS NOT NULL AND accuracy <= ?', ACCURACY_THRESHOLDS[:medium]) }
  scope :by_source, ->(s) { where(source: s) }

  # (keep your PostGIS scope if you want; the spec doesn't use it)
  scope :nearby, ->(lat, lng, radius = 1000) {
    where("ST_DWithin(ST_Point(longitude, latitude), ST_Point(?, ?), ?)", lng, lat, radius)
  }

  # ----- Methods the spec expects -----
  def coordinates = [latitude, longitude]

  # distance to another UserLocation
  def distance_to(other)
    return 0 if other.nil?
    distance_to_coordinates(other.latitude, other.longitude)
  end

  # distance to coordinates (meters) – Haversine
  def distance_to_coordinates(lat, lng)
    return 0 if lat == latitude && lng == longitude

    rad = Math::PI / 180.0
    r_km = 6371.0

    dlat = (lat - latitude) * rad
    dlng = (lng - longitude) * rad
    lat1 = latitude * rad
    lat2 = lat * rad

    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1) * Math.cos(lat2) * Math.sin(dlng / 2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
    (r_km * c * 1000).round
  end

  def accurate? = accuracy.present? && accuracy <= ACCURACY_THRESHOLDS[:medium]
  def recent?   = recorded_at.present? && recorded_at >= RECENT_WINDOW.ago

  def priority
    case accuracy
    when nil then "low"
    when ..ACCURACY_THRESHOLDS[:high]   then "high"
    when ..ACCURACY_THRESHOLDS[:medium] then "medium"
    else "low"
    end
  end

  def accuracy_level = priority
  def location_type  = source
  def actionable?    = accuracy.present? && accuracy <= ACCURACY_THRESHOLDS[:medium]

  def location_data
    { latitude:, longitude:, accuracy:, source:, recorded_at: }
  end

  def summary
    { id:, latitude:, longitude:, accuracy:, source:, recorded_at: }
  end

  def details = summary.merge(coordinates: coordinates)

  def age_hours   = recorded_at ? (Time.current - recorded_at) / 3600.0 : 0
  def age_minutes = recorded_at ? (Time.current - recorded_at) / 60.0   : 0

  def generate_report
    { coordinates:, accuracy:, source:, age: { minutes: age_minutes, hours: age_hours } }
  end

  private

  def ensure_recorded_at_and_source
    self.recorded_at ||= Time.current
    self.source      ||= "gps"
  end
end