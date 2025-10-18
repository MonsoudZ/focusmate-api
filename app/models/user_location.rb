class UserLocation < ApplicationRecord
  belongs_to :user

  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :recorded_at, presence: true

  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(recorded_at: :desc) }
  scope :within_timeframe, ->(start_time, end_time) { where(recorded_at: start_time..end_time) }
  scope :nearby, ->(lat, lng, radius = 1000) {
    where(
      "ST_DWithin(ST_Point(longitude, latitude), ST_Point(?, ?), ?)",
      lng, lat, radius
    )
  }

  # Get coordinates as array
  def coordinates
    [ latitude, longitude ]
  end

  # Get distance to another point
  def distance_to(lat, lng)
    calculate_distance(latitude, longitude, lat, lng)
  end

  # Check if location is accurate enough
  def accurate?
    accuracy.present? && accuracy <= 100 # Within 100 meters
  end

  # Get formatted location string
  def formatted_location
    "#{latitude.round(6)}, #{longitude.round(6)}"
  end

  private

  # Calculate distance between two coordinates using Haversine formula
  def calculate_distance(lat1, lon1, lat2, lon2)
    return 0 if lat1 == lat2 && lon1 == lon2

    # Convert to radians
    lat1_rad = lat1 * Math::PI / 180
    lon1_rad = lon1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    lon2_rad = lon2 * Math::PI / 180

    # Haversine formula
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    a = Math.sin(dlat/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon/2)**2
    c = 2 * Math.asin(Math.sqrt(a))

    # Earth's radius in meters
    6371000 * c
  end
end
