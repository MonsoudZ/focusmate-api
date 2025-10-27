# frozen_string_literal: true

class LocationService
  EARTH_RADIUS_M = 6_371_000.0

  def initialize(lat:, lon:)
    @lat = to_rad(lat)
    @lon = to_rad(lon)
  end

  def distance_to(lat:, lon:)
    lat2 = to_rad(lat)
    lon2 = to_rad(lon)
    dlat = lat2 - @lat
    dlon = lon2 - @lon
    a = Math.sin(dlat / 2)**2 + Math.cos(@lat) * Math.cos(lat2) * Math.sin(dlon / 2)**2
    2 * EARTH_RADIUS_M * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  end

  def within?(center_lat:, center_lon:, radius_m:)
    distance_to(lat: center_lat, lon: center_lon) <= radius_m
  end

  private

  def to_rad(v) = v.to_f * Math::PI / 180.0
end
