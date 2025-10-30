# frozen_string_literal: true

class UserLocation < ApplicationRecord
  # ----- Constants -----
  SOURCES = %w[gps network passive].freeze
  ACCURACY_THRESHOLDS = {
    high: 10,
    medium: 50,
    low: 100
  }.freeze

  # ----- Associations -----
  belongs_to :user

  # ----- Soft delete -----
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete! = update!(deleted_at: Time.current)
  def restore!     = update!(deleted_at: nil)
  def deleted?     = deleted_at.present?

  # ----- Validations -----
  validates :latitude, presence: true,
                      numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
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
  scope :for_user, ->(u) { where(user_id: u.is_a?(User) ? u.id : u) }
  scope :recent, -> { where("recorded_at >= ?", 1.hour.ago) }
  scope :accurate, -> { where("accuracy IS NOT NULL AND accuracy <= ?", 50) }
  scope :by_source, ->(s) { where(source: s) }

  # ----- Simple data accessors -----
  def coordinates = [ latitude, longitude ]

  def recent? = recorded_at.present? && recorded_at >= 1.hour.ago

  def accurate? = accuracy.present? && accuracy <= 50

  # ----- Distance calculations -----
  def distance_to(other_location)
    return nil unless other_location.is_a?(UserLocation)
    distance_to_coordinates(other_location.latitude, other_location.longitude)
  end

  def distance_to_coordinates(lat, lon)
    return nil if lat.nil? || lon.nil?

    # Haversine formula
    earth_radius = 6371000 # meters

    lat1_rad = latitude * Math::PI / 180
    lat2_rad = lat * Math::PI / 180
    delta_lat = (lat - latitude) * Math::PI / 180
    delta_lon = (lon - longitude) * Math::PI / 180

    a = Math.sin(delta_lat / 2) ** 2 +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lon / 2) ** 2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    earth_radius * c
  end

  # ----- Summary methods -----
  def summary
    {
      id: id,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      source: source,
      recorded_at: recorded_at,
      recent: recent?
    }
  end

  def details
    summary.merge(
      coordinates: coordinates,
      age_hours: age_hours,
      age_minutes: age_minutes,
      accurate: accurate?
    )
  end

  def location_data
    {
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      source: source,
      recorded_at: recorded_at,
      coordinates: coordinates,
      timestamp: recorded_at&.iso8601
    }
  end

  def location_report
    {
      summary: summary,
      details: details,
      location_data: location_data
    }
  end

  def generate_report
    {
      coordinates: coordinates,
      accuracy: accuracy,
      source: source,
      age: age_hours
    }
  end

  # ----- Age calculations -----
  def age_hours
    return nil unless recorded_at
    ((Time.current - recorded_at) / 3600).round(2)
  end

  def age_minutes
    return nil unless recorded_at
    ((Time.current - recorded_at) / 60).round(2)
  end

  # ----- Priority and type -----
  def priority
    return "low" unless accuracy.present?

    case accuracy
    when 0...ACCURACY_THRESHOLDS[:high]
      "high"
    when ACCURACY_THRESHOLDS[:high]..ACCURACY_THRESHOLDS[:medium]
      "medium"
    else
      "low"
    end
  end

  def location_type
    source || "unknown"
  end

  def actionable?
    recent? && accurate?
  end

  def accuracy_level
    return nil unless accuracy.present?

    case accuracy
    when 0..ACCURACY_THRESHOLDS[:high]
      "high"
    when ACCURACY_THRESHOLDS[:high]..ACCURACY_THRESHOLDS[:medium]
      "medium"
    else
      "low"
    end
  end

  private

  def ensure_recorded_at_and_source
    self.recorded_at ||= Time.current
    self.source ||= "gps"
  end
end
