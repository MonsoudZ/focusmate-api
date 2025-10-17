class SavedLocation < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true, length: { maximum: 255 }
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :radius_meters, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10000 }
  
  # Scopes
  scope :for_user, ->(user) { where(user: user) }
  scope :nearby, ->(lat, lng, radius = 1000) {
    where(
      "ST_DWithin(ST_Point(longitude, latitude), ST_Point(?, ?), ?)",
      lng, lat, radius
    )
  }
  
  # Get coordinates as array
  def coordinates
    [latitude, longitude]
  end
  
  # Check if a point is within this location's radius
  def contains?(lat, lng)
    distance = calculate_distance(latitude, longitude, lat, lng)
    distance <= radius_meters
  end
  
  # Get distance to another point
  def distance_to(lat, lng)
    calculate_distance(latitude, longitude, lat, lng)
  end
  
  # Get formatted address
  def formatted_address
    return address if address.present?
    "#{name} (#{latitude.round(6)}, #{longitude.round(6)})"
  end

  # Check if user is currently at this location
  def user_at_location?(user)
    return false unless user.current_location
    
    contains?(
      user.current_location.latitude,
      user.current_location.longitude
    )
  end

  # Get nearby saved locations for a user
  def self.nearby_for_user(user, lat, lng, radius = 1000)
    user.saved_locations.nearby(lat, lng, radius)
  end

  # Get location summary for display
  def summary
    {
      id: id,
      name: name,
      coordinates: coordinates,
      radius: radius_meters,
      address: formatted_address
    }
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
