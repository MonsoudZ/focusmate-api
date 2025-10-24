# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedLocation, type: :model do
  let(:user) { create(:user) }
  let(:saved_location) { build(:saved_location, user: user, name: "Test Location", latitude: 40.7128, longitude: -74.0060, radius_meters: 100) }

  describe 'validations' do
    it 'belongs to user' do
      expect(saved_location).to be_valid
      expect(saved_location.user).to eq(user)
    end

    it 'requires name' do
      saved_location.name = nil
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:name]).to include("can't be blank")
    end

    it 'requires latitude' do
      saved_location.latitude = nil
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:latitude]).to include("can't be blank")
    end

    it 'requires longitude' do
      saved_location.longitude = nil
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:longitude]).to include("can't be blank")
    end

    it 'requires radius_meters' do
      saved_location.radius_meters = nil
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:radius_meters]).to include("can't be blank")
    end

    it 'validates latitude bounds' do
      saved_location.latitude = 91
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:latitude]).to include("must be less than or equal to 90")
      
      saved_location.latitude = -91
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:latitude]).to include("must be greater than or equal to -90")
    end

    it 'validates longitude bounds' do
      saved_location.longitude = 181
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:longitude]).to include("must be less than or equal to 180")
      
      saved_location.longitude = -181
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:longitude]).to include("must be greater than or equal to -180")
    end

    it 'validates radius_meters bounds' do
      saved_location.radius_meters = 0
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:radius_meters]).to include("must be greater than 0")
      
      saved_location.radius_meters = 10001
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:radius_meters]).to include("must be less than or equal to 10000")
    end

    it 'validates name length' do
      saved_location.name = "a" * 256
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:name]).to include("is too long (maximum is 255 characters)")
    end

    it 'validates address length' do
      saved_location.address = "a" * 501
      expect(saved_location).not_to be_valid
      expect(saved_location.errors[:address]).to include("is too long (maximum is 500 characters)")
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(saved_location.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has for_user scope' do
      other_user = create(:user)
      user_location = create(:saved_location, user: user)
      other_location = create(:saved_location, user: other_user)
      
      expect(SavedLocation.for_user(user)).to include(user_location)
      expect(SavedLocation.for_user(user)).not_to include(other_location)
    end

    it 'has nearby scope' do
      location1 = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060)
      location2 = create(:saved_location, user: user, latitude: 40.8000, longitude: -74.0000)
      
      nearby = SavedLocation.nearby(40.7128, -74.0060, 1000)
      expect(nearby).to include(location1)
      expect(nearby).not_to include(location2)
    end
  end

  describe 'methods' do
    it 'returns coordinates as array' do
      expect(saved_location.coordinates).to eq([40.7128, -74.0060])
    end

    it 'checks if point is within radius' do
      # Point within radius
      expect(saved_location.contains?(40.7128, -74.0060)).to be true
      
      # Point outside radius
      expect(saved_location.contains?(40.8000, -74.0000)).to be false
    end

    it 'calculates distance to point' do
      distance = saved_location.distance_to(40.7130, -74.0060)
      expect(distance).to be < 100 # Should be very close
    end

    it 'returns formatted address' do
      saved_location.address = "123 Main St, New York, NY"
      expect(saved_location.formatted_address).to eq("123 Main St, New York, NY")
    end

    it 'returns coordinates when no address' do
      saved_location.address = nil
      expect(saved_location.formatted_address).to include("40.7128")
      expect(saved_location.formatted_address).to include("-74.0060")
    end

    it 'checks if user is at location' do
      user.update!(latitude: 40.7128, longitude: -74.0060)
      expect(saved_location.user_at_location?(user)).to be true
      
      user.update!(latitude: 40.8000, longitude: -74.0000)
      expect(saved_location.user_at_location?(user)).to be false
    end

    it 'returns nearby saved locations for user' do
      other_location = create(:saved_location, user: user, latitude: 40.7130, longitude: -74.0060)
      far_location = create(:saved_location, user: user, latitude: 40.8000, longitude: -74.0000)
      
      nearby = SavedLocation.nearby_for_user(user, 40.7128, -74.0060, 1000)
      expect(nearby).to include(other_location)
      expect(nearby).not_to include(far_location)
    end

    it 'returns location summary' do
      summary = saved_location.summary
      expect(summary).to include(:id, :name, :coordinates, :radius, :address)
    end

    it 'calculates distance accurately' do
      # Test with known coordinates (NYC to LA)
      nyc_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060)
      la_lat, la_lng = 34.0522, -118.2437
      
      distance = nyc_location.distance_to(la_lat, la_lng)
      expect(distance).to be > 3000000 # Should be over 3000km
      expect(distance).to be < 5000000 # Should be under 5000km
    end

    it 'handles edge cases at poles' do
      north_pole_location = create(:saved_location, user: user, latitude: 90, longitude: 0)
      south_pole_location = create(:saved_location, user: user, latitude: -90, longitude: 0)
      
      expect(north_pole_location.coordinates).to eq([90, 0])
      expect(south_pole_location.coordinates).to eq([-90, 0])
    end

    it 'handles zero distance' do
      expect(saved_location.distance_to(40.7128, -74.0060)).to eq(0)
    end

    it 'handles very small radius' do
      small_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060, radius_meters: 1)
      expect(small_location.contains?(40.7128, -74.0060)).to be true
      expect(small_location.contains?(40.7130, -74.0060)).to be false
    end

    it 'handles very large radius' do
      large_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060, radius_meters: 10000)
      expect(large_location.contains?(40.8000, -74.0000)).to be true
    end
  end

  describe 'callbacks' do
    it 'sets default values before validation' do
      sl = build(:saved_location, user: user,
        name: "Test Location", latitude: 40.7128, longitude: -74.0060
        # radius_meters intentionally omitted
      )
      sl.valid?
      expect(sl.radius_meters).to eq(100)
    end

    it 'does not override existing values' do
      saved_location.radius_meters = 500
      saved_location.valid?
      expect(saved_location.radius_meters).to eq(500)
    end
  end

  describe 'soft deletion' do
    it 'soft deletes saved location' do
      saved_location.save!
      saved_location.soft_delete!
      expect(saved_location.deleted?).to be true
      expect(saved_location.deleted_at).not_to be_nil
    end

    it 'restores soft deleted saved location' do
      saved_location.save!
      saved_location.soft_delete!
      saved_location.restore!
      expect(saved_location.deleted?).to be false
      expect(saved_location.deleted_at).to be_nil
    end

    it 'excludes soft deleted locations from default scope' do
      saved_location.save!
      saved_location.soft_delete!
      expect(SavedLocation.all).not_to include(saved_location)
      expect(SavedLocation.with_deleted).to include(saved_location)
    end
  end

  describe 'geocoding' do
    it 'geocodes address to coordinates' do
      saved_location.address = "Times Square, New York, NY"
      saved_location.latitude = nil
      saved_location.longitude = nil
      
      # Mock geocoding response
      allow(Geocoder).to receive(:search).and_return([double(latitude: 40.7580, longitude: -73.9855)])
      
      saved_location.geocode
      expect(saved_location.latitude).to eq(40.7580)
      expect(saved_location.longitude).to eq(-73.9855)
    end

    it 'handles geocoding errors gracefully' do
      saved_location.address = "Invalid Address"
      saved_location.latitude = nil
      saved_location.longitude = nil
      
      allow(Geocoder).to receive(:search).and_return([])
      
      saved_location.geocode
      expect(saved_location.latitude).to be_nil
      expect(saved_location.longitude).to be_nil
    end
  end

  describe 'distance calculations' do
    it 'calculates distance using Haversine formula' do
      # Test with known distance (NYC to Philadelphia)
      nyc_location = create(:saved_location, user: user, latitude: 40.7128, longitude: -74.0060)
      philly_lat, philly_lng = 39.9526, -75.1652
      
      distance = nyc_location.distance_to(philly_lat, philly_lng)
      expect(distance).to be > 80000 # Should be over 80km
      expect(distance).to be < 130000 # Should be under 130km
    end

    it 'handles coordinates at same location' do
      expect(saved_location.distance_to(40.7128, -74.0060)).to eq(0)
    end

    it 'handles coordinates at opposite sides of the world' do
      # Test with coordinates that are 180 degrees apart
      location1 = create(:saved_location, user: user, latitude: 0, longitude: 0)
      distance = location1.distance_to(0, 180)
      expect(distance).to be > 20000000 # Should be over 20,000km
    end
  end

  describe 'user location integration' do
    it 'checks if user is currently at location' do
      user.update!(latitude: 40.7128, longitude: -74.0060)
      expect(saved_location.user_at_location?(user)).to be true
      
      user.update!(latitude: 40.8000, longitude: -74.0000)
      expect(saved_location.user_at_location?(user)).to be false
    end

    it 'handles user without current location' do
      user.update!(latitude: nil, longitude: nil)
      expect(saved_location.user_at_location?(user)).to be false
    end
  end

  describe 'location management' do
    it 'creates location with coordinates' do
      location = SavedLocation.create!(
        user: user,
        name: "Test Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      )
      expect(location).to be_persisted
      expect(location.coordinates).to eq([40.7128, -74.0060])
    end

    it 'creates location with address' do
      location = SavedLocation.create!(
        user: user,
        name: "Test Location",
        address: "Times Square, New York, NY",
        radius_meters: 100
      )
      expect(location).to be_persisted
      expect(location.address).to eq("Times Square, New York, NY")
    end

    it 'updates location coordinates' do
      saved_location.save!
      saved_location.update!(latitude: 40.8000, longitude: -74.0000)
      expect(saved_location.coordinates).to eq([40.8000, -74.0000])
    end

    it 'updates location address' do
      saved_location.save!
      saved_location.update!(address: "Updated Address")
      expect(saved_location.address).to eq("Updated Address")
    end
  end
end
