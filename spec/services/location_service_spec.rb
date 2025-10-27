# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LocationService do
  describe '#distance_to' do
    it 'computes short distances reasonably' do
      # Denver coordinates
      a = described_class.new(lat: 39.7392, lon: -104.9903)
      # Nearby point in Denver
      distance = a.distance_to(lat: 39.7420, lon: -104.9915)
      expect(distance).to be_between(0, 5000) # Should be within 5km
    end

    it 'computes zero distance for same coordinates' do
      service = described_class.new(lat: 40.7128, lon: -74.0060) # NYC
      distance = service.distance_to(lat: 40.7128, lon: -74.0060)
      expect(distance).to eq(0)
    end

    it 'computes distance between major cities' do
      # NYC to LA (approximately 3944 km)
      nyc = described_class.new(lat: 40.7128, lon: -74.0060)
      la_distance = nyc.distance_to(lat: 34.0522, lon: -118.2437)
      expect(la_distance).to be_between(3_900_000, 4_000_000) # Within 100km tolerance
    end

    it 'handles negative coordinates' do
      # Sydney, Australia
      sydney = described_class.new(lat: -33.8688, lon: 151.2093)
      # Melbourne, Australia (approximately 713 km)
      melbourne_distance = sydney.distance_to(lat: -37.8136, lon: 144.9631)
      expect(melbourne_distance).to be_between(700_000, 750_000)
    end
  end

  describe '#within?' do
    it 'returns true for coordinates within radius' do
      center = described_class.new(lat: 40.7128, lon: -74.0060) # NYC
      # Point 1km away
      nearby_point = { center_lat: 40.7218, center_lon: -74.0060 }
      expect(center.within?(**nearby_point, radius_m: 2000)).to be true
    end

    it 'returns false for coordinates outside radius' do
      center = described_class.new(lat: 40.7128, lon: -74.0060) # NYC
      # Point 100km away
      far_point = { center_lat: 41.7128, center_lon: -74.0060 }
      expect(center.within?(**far_point, radius_m: 1000)).to be false
    end

    it 'returns true for coordinates exactly at radius boundary' do
      center = described_class.new(lat: 40.7128, lon: -74.0060) # NYC
      # Point exactly 1km away
      boundary_point = { center_lat: 40.7218, center_lon: -74.0060 }
      distance = center.distance_to(lat: 40.7218, lon: -74.0060)
      expect(center.within?(**boundary_point, radius_m: distance)).to be true
    end
  end

  describe 'edge cases' do
    it 'handles string coordinates' do
      service = described_class.new(lat: "40.7128", lon: "-74.0060")
      distance = service.distance_to(lat: "40.7218", lon: "-74.0060")
      expect(distance).to be > 0
    end

    it 'handles very small distances' do
      service = described_class.new(lat: 40.7128, lon: -74.0060)
      # Very close point (about 1 meter)
      distance = service.distance_to(lat: 40.7128001, lon: -74.0060001)
      expect(distance).to be_between(0, 100) # Less than 100 meters
    end

    it 'handles coordinates at poles' do
      # North Pole
      north_pole = described_class.new(lat: 90.0, lon: 0.0)
      # Point 1 degree south
      distance = north_pole.distance_to(lat: 89.0, lon: 0.0)
      expect(distance).to be_between(100_000, 120_000) # About 111km per degree
    end
  end
end
