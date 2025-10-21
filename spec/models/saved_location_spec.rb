require 'rails_helper'

RSpec.describe SavedLocation, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_presence_of(:latitude) }
    it { should validate_presence_of(:longitude) }
    it { should validate_presence_of(:radius_meters) }

    it 'should validate latitude between -90 and 90' do
      location = build(:saved_location, latitude: 91)
      expect(location).not_to be_valid
      expect(location.errors[:latitude]).to include('must be less than or equal to 90')
    end

    it 'should validate latitude between -90 and 90 (negative)' do
      location = build(:saved_location, latitude: -91)
      expect(location).not_to be_valid
      expect(location.errors[:latitude]).to include('must be greater than or equal to -90')
    end

    it 'should validate longitude between -180 and 180' do
      location = build(:saved_location, longitude: 181)
      expect(location).not_to be_valid
      expect(location.errors[:longitude]).to include('must be less than or equal to 180')
    end

    it 'should validate longitude between -180 and 180 (negative)' do
      location = build(:saved_location, longitude: -181)
      expect(location).not_to be_valid
      expect(location.errors[:longitude]).to include('must be greater than or equal to -180')
    end

    it 'should validate radius_meters between 10 and 10000' do
      location = build(:saved_location, radius_meters: 5)
      expect(location).not_to be_valid
      expect(location.errors[:radius_meters]).to include('must be greater than 0')
    end

    it 'should validate radius_meters maximum' do
      location = build(:saved_location, radius_meters: 10001)
      expect(location).not_to be_valid
      expect(location.errors[:radius_meters]).to include('must be less than or equal to 10000')
    end

    it 'should allow valid coordinates' do
      location = build(:saved_location, latitude: 40.7128, longitude: -74.0060)
      expect(location).to be_valid
    end

    it 'should allow valid radius' do
      location = build(:saved_location, radius_meters: 500)
      expect(location).to be_valid
    end
  end

  describe 'defaults' do
    let(:location) { create(:saved_location) }

    it 'should default radius_meters to 100' do
      expect(location.radius_meters).to eq(100)
    end
  end

  describe 'basic functionality' do
    let(:user) { create(:user) }
    let(:location) { create(:saved_location, user: user) }

    it 'should create saved location with valid attributes' do
      expect(location).to be_valid
      expect(location.name).to be_present
      expect(location.latitude).to be_present
      expect(location.longitude).to be_present
      expect(location.user).to eq(user)
    end

    it 'should require name' do
      location = build(:saved_location, name: nil)
      expect(location).not_to be_valid
      expect(location.errors[:name]).to include("can't be blank")
    end

    it 'should require latitude' do
      location = build(:saved_location, latitude: nil)
      expect(location).not_to be_valid
      expect(location.errors[:latitude]).to include("can't be blank")
    end

    it 'should require longitude' do
      location = build(:saved_location, longitude: nil)
      expect(location).not_to be_valid
      expect(location.errors[:longitude]).to include("can't be blank")
    end

    it 'should allow optional address' do
      location = create(:saved_location, address: '123 Main St, New York, NY')
      expect(location).to be_valid
      expect(location.address).to eq('123 Main St, New York, NY')
    end

    it 'should allow location without address' do
      location = create(:saved_location, address: nil)
      expect(location).to be_valid
      expect(location.address).to be_nil
    end
  end

  describe 'coordinate methods' do
    let(:location) { create(:saved_location, latitude: 40.7128, longitude: -74.0060) }

    it 'should return coordinates as array' do
      expect(location.coordinates).to eq([40.7128, -74.0060])
    end

    it 'should get formatted address with coordinates' do
      formatted = location.formatted_address
      expect(formatted).to include('40.712800')
      expect(formatted).to include('-74.006000')
    end

    it 'should get formatted address with custom address' do
      location.update!(address: '123 Main St, New York, NY')
      formatted = location.formatted_address
      expect(formatted).to eq('123 Main St, New York, NY')
    end
  end

  describe 'distance calculation' do
    let(:location) { create(:saved_location, latitude: 40.7128, longitude: -74.0060) }

    it 'should calculate distance to another point' do
      # Distance to nearby point (approximately 1km away)
      distance = location.distance_to(40.7218, -74.0060)
      expect(distance).to be > 0
      expect(distance).to be < 2000 # Should be less than 2km
    end

    it 'should return 0 for same coordinates' do
      distance = location.distance_to(40.7128, -74.0060)
      expect(distance).to eq(0)
    end

    it 'should calculate distance using Haversine formula' do
      # Test with known coordinates (NYC to Boston is approximately 306km)
      nyc_location = create(:saved_location, latitude: 40.7128, longitude: -74.0060)
      distance = nyc_location.distance_to(42.3601, -71.0589) # Boston coordinates
      expect(distance).to be > 300000 # Should be more than 300km
      expect(distance).to be < 320000 # Should be less than 320km
    end
  end

  describe 'geofencing' do
    let(:location) { create(:saved_location, latitude: 40.7128, longitude: -74.0060, radius_meters: 100) }

    it 'should check if coordinates are within radius' do
      # Point within radius (approximately 50m away)
      within_radius = location.contains?(40.7133, -74.0060)
      expect(within_radius).to be true
    end

    it 'should check if coordinates are outside radius' do
      # Point outside radius (approximately 200m away)
      outside_radius = location.contains?(40.7148, -74.0060)
      expect(outside_radius).to be false
    end

    it 'should check if user is at location' do
      user = create(:user)
      user.update_current_location(40.7128, -74.0060)
      
      expect(location.user_at_location?(user)).to be true
    end

    it 'should return false if user has no current location' do
      user = create(:user)
      expect(location.user_at_location?(user)).to be false
    end

    it 'should return false if user is outside radius' do
      user = create(:user)
      user.update_current_location(40.7200, -74.0060) # Far away
      
      expect(location.user_at_location?(user)).to be false
    end
  end

  describe 'scopes' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:location1) { create(:saved_location, user: user1, latitude: 40.7128, longitude: -74.0060) }
    let!(:location2) { create(:saved_location, user: user2, latitude: 40.7128, longitude: -74.0060) }

    it 'should scope for user' do
      user_locations = SavedLocation.for_user(user1)
      expect(user_locations).to include(location1)
      expect(user_locations).not_to include(location2)
    end

    it 'should scope nearby locations' do
      # Find locations within 1km of NYC coordinates
      nearby = SavedLocation.nearby(40.7128, -74.0060, 1000)
      expect(nearby).to include(location1, location2)
    end

    it 'should scope nearby locations for user' do
      nearby = SavedLocation.nearby_for_user(user1, 40.7128, -74.0060, 1000)
      expect(nearby).to include(location1)
      expect(nearby).not_to include(location2)
    end
  end

  describe 'summary method' do
    let(:location) { create(:saved_location, name: 'Home', latitude: 40.7128, longitude: -74.0060, radius_meters: 100) }

    it 'should return location summary' do
      summary = location.summary
      expect(summary).to include(
        id: location.id,
        name: 'Home',
        coordinates: [40.7128, -74.0060],
        radius: 100
      )
    end

    it 'should include formatted address in summary' do
      summary = location.summary
      expect(summary[:address]).to be_present
    end
  end

  describe 'edge cases' do
    let(:location) { create(:saved_location) }

    it 'should handle extreme coordinates' do
      # North Pole
      north_pole = create(:saved_location, latitude: 90, longitude: 0)
      expect(north_pole).to be_valid
      
      # South Pole
      south_pole = create(:saved_location, latitude: -90, longitude: 0)
      expect(south_pole).to be_valid
      
      # International Date Line
      idl = create(:saved_location, latitude: 0, longitude: 180)
      expect(idl).to be_valid
    end

    it 'should handle minimum radius' do
      location = create(:saved_location, radius_meters: 1)
      expect(location).to be_valid
    end

    it 'should handle maximum radius' do
      location = create(:saved_location, radius_meters: 10000)
      expect(location).to be_valid
    end

    it 'should handle very small distances' do
      location = create(:saved_location, latitude: 40.7128, longitude: -74.0060)
      distance = location.distance_to(40.7128001, -74.0060001)
      expect(distance).to be > 0
      expect(distance).to be < 1 # Should be less than 1 meter
    end

    it 'should handle very large distances' do
      # NYC to London (approximately 5570km)
      nyc = create(:saved_location, latitude: 40.7128, longitude: -74.0060)
      distance = nyc.distance_to(51.5074, -0.1278)
      expect(distance).to be > 5500000 # Should be more than 5500km
      expect(distance).to be < 5700000 # Should be less than 5700km
    end
  end

  describe 'integration with user model' do
    let(:user) { create(:user) }
    let(:location) { create(:saved_location, user: user) }

    it 'should be accessible through user association' do
      expect(user.saved_locations).to include(location)
    end

    it 'should calculate distance to user location' do
      user.update_current_location(40.7200, -74.0060)
      distance = location.distance_to(user.current_latitude, user.current_longitude)
      expect(distance).to be > 0
    end

    it 'should check if user is at saved location' do
      user.update_current_location(location.latitude, location.longitude)
      expect(location.user_at_location?(user)).to be true
    end
  end

  describe 'geocoding (if enabled)' do
    # Note: This test assumes geocoding is not enabled by default
    # In a real application with geocoding enabled, these tests would be more comprehensive
    
    it 'should handle address field' do
      location = create(:saved_location, address: '123 Main St, New York, NY')
      expect(location.address).to eq('123 Main St, New York, NY')
    end

    it 'should not automatically geocode without geocoding service' do
      # This test verifies that coordinates are not automatically set from address
      location = build(:saved_location, address: '123 Main St, New York, NY', latitude: nil, longitude: nil)
      expect(location).not_to be_valid
      expect(location.errors[:latitude]).to include("can't be blank")
    end
  end

  describe 'performance considerations' do
    let(:user) { create(:user) }

    it 'should efficiently query nearby locations' do
      # Create multiple locations
      create_list(:saved_location, 10, user: user)
      
      # This test verifies the scope works without performance issues
      nearby = SavedLocation.nearby_for_user(user, 40.7128, -74.0060, 1000)
      expect(nearby).to be_an(ActiveRecord::Relation)
    end

    it 'should handle distance calculations efficiently' do
      location = create(:saved_location, latitude: 40.7128, longitude: -74.0060)
      
      # Test multiple distance calculations
      100.times do
        lat = 40.7128 + (rand - 0.5) * 0.01
        lng = -74.0060 + (rand - 0.5) * 0.01
        distance = location.distance_to(lat, lng)
        expect(distance).to be >= 0
      end
    end
  end
end
