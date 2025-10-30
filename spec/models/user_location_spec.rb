# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserLocation, type: :model do
  let(:user) { create(:user) }
  let(:user_location) { build(:user_location, user: user, latitude: 40.7128, longitude: -74.0060, accuracy: 10.0, recorded_at: Time.current) }

  describe 'validations' do
    it 'belongs to user' do
      expect(user_location).to be_valid
      expect(user_location.user).to eq(user)
    end

    it 'requires latitude' do
      user_location.latitude = nil
      expect(user_location).not_to be_valid
      expect(user_location.errors[:latitude]).to include("can't be blank")
    end

    it 'requires longitude' do
      user_location.longitude = nil
      expect(user_location).not_to be_valid
      expect(user_location.errors[:longitude]).to include("can't be blank")
    end

    it 'requires recorded_at' do
      # Skip the callback to test validation directly
      user_location.define_singleton_method(:ensure_recorded_at_and_source) { }
      user_location.recorded_at = nil
      expect(user_location).not_to be_valid
      expect(user_location.errors[:recorded_at]).to include("can't be blank")
    end

    it 'validates latitude bounds' do
      user_location.latitude = 91
      expect(user_location).not_to be_valid
      expect(user_location.errors[:latitude]).to include("must be less than or equal to 90")

      user_location.latitude = -91
      expect(user_location).not_to be_valid
      expect(user_location.errors[:latitude]).to include("must be greater than or equal to -90")
    end

    it 'validates longitude bounds' do
      user_location.longitude = 181
      expect(user_location).not_to be_valid
      expect(user_location.errors[:longitude]).to include("must be less than or equal to 180")

      user_location.longitude = -181
      expect(user_location).not_to be_valid
      expect(user_location.errors[:longitude]).to include("must be greater than or equal to -180")
    end

    it 'validates accuracy bounds' do
      user_location.accuracy = -1
      expect(user_location).not_to be_valid
      expect(user_location.errors[:accuracy]).to include("must be greater than or equal to 0")

      user_location.accuracy = 1001
      expect(user_location).not_to be_valid
      expect(user_location.errors[:accuracy]).to include("must be less than or equal to 1000")
    end

    it 'allows nil accuracy' do
      user_location.accuracy = nil
      expect(user_location).to be_valid
    end

    it 'validates source inclusion' do
      user_location.source = "invalid_source"
      expect(user_location).not_to be_valid
      expect(user_location.errors[:source]).to include("is not included in the list")
    end

    it 'allows nil source' do
      user_location.source = nil
      expect(user_location).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      expect(user_location.user).to eq(user)
    end
  end

  describe 'scopes' do
    it 'has for_user scope' do
      other_user = create(:user)
      user_location_record = create(:user_location, user: user)
      other_location = create(:user_location, user: other_user)

      expect(UserLocation.for_user(user)).to include(user_location_record)
      expect(UserLocation.for_user(user)).not_to include(other_location)
    end

    it 'has recent scope' do
      recent_location = create(:user_location, user: user, recorded_at: 30.minutes.ago)
      old_location = create(:user_location, user: user, recorded_at: 2.hours.ago)

      expect(UserLocation.recent).to include(recent_location)
      expect(UserLocation.recent).not_to include(old_location)
    end

    it 'has accurate scope' do
      accurate_location = create(:user_location, user: user, accuracy: 5.0)
      inaccurate_location = create(:user_location, user: user, accuracy: 100.0)

      expect(UserLocation.accurate).to include(accurate_location)
      expect(UserLocation.accurate).not_to include(inaccurate_location)
    end

    it 'has by_source scope' do
      gps_location = create(:user_location, user: user, source: "gps")
      network_location = create(:user_location, user: user, source: "network")

      expect(UserLocation.by_source("gps")).to include(gps_location)
      expect(UserLocation.by_source("gps")).not_to include(network_location)
    end
  end

  describe 'methods' do
    it 'returns coordinates as array' do
      expect(user_location.coordinates).to eq([ 40.7128, -74.0060 ])
    end

    it 'calculates distance to another location' do
      other_location = create(:user_location, user: user, latitude: 40.7130, longitude: -74.0060)
      distance = user_location.distance_to(other_location)
      expect(distance).to be < 100 # Should be very close
    end

    it 'calculates distance to coordinates' do
      distance = user_location.distance_to_coordinates(40.7130, -74.0060)
      expect(distance).to be < 100 # Should be very close
    end

    it 'checks if location is accurate' do
      accurate_location = create(:user_location, user: user, accuracy: 5.0)
      inaccurate_location = create(:user_location, user: user, accuracy: 100.0)

      expect(accurate_location.accurate?).to be true
      expect(inaccurate_location.accurate?).to be false
    end

    it 'checks if location is recent' do
      recent_location = create(:user_location, user: user, recorded_at: 30.minutes.ago)
      old_location = create(:user_location, user: user, recorded_at: 2.hours.ago)

      expect(recent_location.recent?).to be true
      expect(old_location.recent?).to be false
    end

    it 'returns location summary' do
      user_location.accuracy = 10.0
      user_location.source = "gps"

      summary = user_location.summary
      expect(summary).to include(:id, :latitude, :longitude, :accuracy, :source, :recorded_at)
    end

    it 'returns location details' do
      user_location.accuracy = 10.0
      user_location.source = "gps"

      details = user_location.details
      expect(details).to include(:id, :latitude, :longitude, :accuracy, :source, :recorded_at, :coordinates)
    end

    it 'returns age in hours' do
      user_location.recorded_at = 2.hours.ago
      expect(user_location.age_hours).to be >= 2
    end

    it 'returns age in minutes' do
      user_location.recorded_at = 30.minutes.ago
      expect(user_location.age_minutes).to be >= 30
    end

    it 'returns priority level' do
      user_location.accuracy = 5.0
      expect(user_location.priority).to eq("high")

      user_location.accuracy = 50.0
      expect(user_location.priority).to eq("medium")

      user_location.accuracy = 100.0
      expect(user_location.priority).to eq("low")
    end

    it 'returns location type' do
      user_location.source = "gps"
      expect(user_location.location_type).to eq("gps")

      user_location.source = "network"
      expect(user_location.location_type).to eq("network")

      user_location.source = "passive"
      expect(user_location.location_type).to eq("passive")
    end

    it 'checks if location is actionable' do
      user_location.accuracy = 10.0
      expect(user_location.actionable?).to be true

      user_location.accuracy = 100.0
      expect(user_location.actionable?).to be false
    end

    it 'returns location data' do
      user_location.accuracy = 10.0
      user_location.source = "gps"

      data = user_location.location_data
      expect(data).to include(:latitude, :longitude, :accuracy, :source, :recorded_at)
    end

    it 'generates location report' do
      user_location.accuracy = 10.0
      user_location.source = "gps"

      report = user_location.generate_report
      expect(report).to include(:coordinates, :accuracy, :source, :age)
    end
  end

  describe 'callbacks' do
    it 'sets default recorded_at before validation' do
      user_location.recorded_at = nil
      user_location.valid?
      expect(user_location.recorded_at).not_to be_nil
    end

    it 'does not override existing recorded_at' do
      original_time = 1.hour.ago
      user_location.recorded_at = original_time
      user_location.valid?
      expect(user_location.recorded_at).to eq(original_time)
    end

    it 'sets default source before validation' do
      user_location.source = nil
      user_location.valid?
      expect(user_location.source).to eq("gps")
    end

    it 'does not override existing source' do
      user_location.source = "network"
      user_location.valid?
      expect(user_location.source).to eq("network")
    end
  end

  describe 'soft deletion' do
    it 'soft deletes user location' do
      user_location.save!
      user_location.soft_delete!
      expect(user_location.deleted?).to be true
      expect(user_location.deleted_at).not_to be_nil
    end

    it 'restores soft deleted user location' do
      user_location.save!
      user_location.soft_delete!
      user_location.restore!
      expect(user_location.deleted?).to be false
      expect(user_location.deleted_at).to be_nil
    end

    it 'excludes soft deleted locations from default scope' do
      user_location.save!
      user_location.soft_delete!
      expect(UserLocation.all).not_to include(user_location)
      expect(UserLocation.with_deleted).to include(user_location)
    end
  end

  describe 'location tracking' do
    it 'tracks user location' do
      location = UserLocation.create!(
        user: user,
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 10.0,
        source: "gps"
      )
      expect(location).to be_persisted
      expect(location.coordinates).to eq([ 40.7128, -74.0060 ])
    end

    it 'tracks location with different sources' do
      gps_location = create(:user_location, user: user, source: "gps")
      network_location = create(:user_location, user: user, source: "network")
      passive_location = create(:user_location, user: user, source: "passive")

      expect(gps_location.source).to eq("gps")
      expect(network_location.source).to eq("network")
      expect(passive_location.source).to eq("passive")
    end

    it 'tracks location accuracy' do
      accurate_location = create(:user_location, user: user, accuracy: 5.0)
      inaccurate_location = create(:user_location, user: user, accuracy: 100.0)

      expect(accurate_location.accurate?).to be true
      expect(inaccurate_location.accurate?).to be false
    end
  end

  describe 'distance calculations' do
    it 'calculates distance using Haversine formula' do
      # Test with known distance (NYC to Philadelphia)
      nyc_location = create(:user_location, user: user, latitude: 40.7128, longitude: -74.0060)
      philly_lat, philly_lng = 39.9526, -75.1652

      distance = nyc_location.distance_to_coordinates(philly_lat, philly_lng)
      expect(distance).to be > 80_000 # Should be over 80km
      expect(distance).to be < 140_000 # Should be under 140km (real value ≈ 129.6km)
    end

    it 'handles coordinates at same location' do
      expect(user_location.distance_to_coordinates(40.7128, -74.0060)).to eq(0)
    end

    it 'handles coordinates at opposite sides of the world' do
      # Test with coordinates that are 180 degrees apart
      location1 = create(:user_location, user: user, latitude: 0, longitude: 0)
      distance = location1.distance_to_coordinates(0, 180)
      expect(distance).to be > 20000000 # Should be over 20,000km
    end
  end

  describe 'user location history' do
    it 'returns user location history' do
      location1 = create(:user_location, user: user, recorded_at: 1.hour.ago)
      location2 = create(:user_location, user: user, recorded_at: 30.minutes.ago)

      history = UserLocation.for_user(user).order(:recorded_at)
      expect(history).to include(location1, location2)
    end

    it 'returns recent locations for user' do
      recent_location = create(:user_location, user: user, recorded_at: 30.minutes.ago)
      old_location = create(:user_location, user: user, recorded_at: 2.hours.ago)

      recent_locations = UserLocation.for_user(user).recent
      expect(recent_locations).to include(recent_location)
      expect(recent_locations).not_to include(old_location)
    end

    it 'returns accurate locations for user' do
      accurate_location = create(:user_location, user: user, accuracy: 5.0)
      inaccurate_location = create(:user_location, user: user, accuracy: 100.0)

      accurate_locations = UserLocation.for_user(user).accurate
      expect(accurate_locations).to include(accurate_location)
      expect(accurate_locations).not_to include(inaccurate_location)
    end
  end

  describe 'location accuracy' do
    it 'defines accuracy thresholds' do
      expect(UserLocation::ACCURACY_THRESHOLDS[:high]).to eq(10)
      expect(UserLocation::ACCURACY_THRESHOLDS[:medium]).to eq(50)
      expect(UserLocation::ACCURACY_THRESHOLDS[:low]).to eq(100)
    end

    it 'classifies accuracy levels' do
      high_accuracy = create(:user_location, user: user, accuracy: 5.0)
      medium_accuracy = create(:user_location, user: user, accuracy: 30.0)
      low_accuracy = create(:user_location, user: user, accuracy: 80.0)

      expect(high_accuracy.accuracy_level).to eq("high")
      expect(medium_accuracy.accuracy_level).to eq("medium")
      expect(low_accuracy.accuracy_level).to eq("low")
    end
  end

  describe 'location sources' do
    it 'defines valid sources' do
      expect(UserLocation::SOURCES).to include("gps", "network", "passive")
    end

    it 'validates source inclusion' do
      UserLocation::SOURCES.each do |source|
        location = build(:user_location, user: user, source: source)
        expect(location).to be_valid
      end
    end
  end

  describe 'location metadata' do
    it 'stores location metadata' do
      user_location.metadata = { "speed" => 5.5, "heading" => 180 }
      expect(user_location).to be_valid
      expect(user_location.metadata["speed"]).to eq(5.5)
      expect(user_location.metadata["heading"]).to eq(180)
    end

    it 'handles empty metadata' do
      user_location.metadata = {}
      expect(user_location).to be_valid
      expect(user_location.metadata).to eq({})
    end

    it 'validates metadata structure' do
      user_location.metadata = { "invalid" => "structure" }
      expect(user_location).to be_valid
    end
  end
end
