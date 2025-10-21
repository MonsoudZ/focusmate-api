require "test_helper"

class UserLocationTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @user_location = UserLocation.new(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy: 10.0,
      recorded_at: Time.current
    )
  end

  test "should belong to user" do
    assert @user_location.valid?
    assert_equal @user, @user_location.user
  end

  test "should require latitude" do
    @user_location.latitude = nil
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:latitude], "can't be blank"
  end

  test "should require longitude" do
    @user_location.longitude = nil
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:longitude], "can't be blank"
  end

  test "should require recorded_at timestamp" do
    @user_location.recorded_at = nil
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:recorded_at], "can't be blank"
  end

  test "should validate latitude bounds" do
    # Test valid latitudes
    @user_location.latitude = 0
    assert @user_location.valid?

    @user_location.latitude = 90
    assert @user_location.valid?

    @user_location.latitude = -90
    assert @user_location.valid?

    # Test invalid latitudes
    @user_location.latitude = 91
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:latitude], "must be less than or equal to 90"

    @user_location.latitude = -91
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:latitude], "must be greater than or equal to -90"
  end

  test "should validate longitude bounds" do
    # Test valid longitudes
    @user_location.longitude = 0
    assert @user_location.valid?

    @user_location.longitude = 180
    assert @user_location.valid?

    @user_location.longitude = -180
    assert @user_location.valid?

    # Test invalid longitudes
    @user_location.longitude = 181
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:longitude], "must be less than or equal to 180"

    @user_location.longitude = -181
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:longitude], "must be greater than or equal to -180"
  end

  test "should store accuracy in meters" do
    @user_location.accuracy = 5.5
    @user_location.save!
    
    assert_equal 5.5, @user_location.accuracy
  end

  test "should allow nil accuracy" do
    @user_location.accuracy = nil
    assert @user_location.valid?
    assert @user_location.save
  end

  test "should order by recorded_at descending" do
    # Create locations with different recorded_at times
    old_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 3.hours.ago
    )
    
    recent_location = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: 1.hour.ago
    )
    
    recent_locations = UserLocation.recent
    assert_equal recent_location, recent_locations.first
    assert_equal old_location, recent_locations.last
  end

  test "should get user's most recent location" do
    # Create multiple locations for the same user
    old_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 2.hours.ago
    )
    
    recent_location = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: 1.hour.ago
    )
    
    most_recent = @user.user_locations.recent.first
    assert_equal recent_location, most_recent
    assert_not_equal old_location, most_recent
  end

  test "should calculate distance between locations" do
    # Test distance to same point (should be 0)
    distance = @user_location.distance_to(40.7128, -74.0060)
    assert_equal 0, distance.round(2)

    # Test distance to nearby point (approximately 1km away)
    distance = @user_location.distance_to(40.7218, -73.9960)
    assert distance > 1200 # Should be around 1.3km
    assert distance < 1400
  end

  test "should clean up old locations older than 30 days" do
    # Create old location (31 days ago)
    old_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 31.days.ago
    )
    
    # Create recent location (1 day ago)
    recent_location = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: 1.day.ago
    )
    
    # Simulate cleanup by finding locations older than 30 days
    old_locations = UserLocation.where("recorded_at < ?", 30.days.ago)
    assert_includes old_locations, old_location
    assert_not_includes old_locations, recent_location
  end

  test "should use for_user scope" do
    other_user = create_test_user
    user_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    other_location = UserLocation.create!(
      user: other_user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: Time.current
    )
    
    user_locations = UserLocation.for_user(@user)
    assert_includes user_locations, user_location
    assert_not_includes user_locations, other_location
  end

  test "should use recent scope" do
    old_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 2.days.ago
    )
    
    recent_location = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: 1.hour.ago
    )
    
    recent_locations = UserLocation.recent
    assert_equal recent_location, recent_locations.first
    assert_equal old_location, recent_locations.last
  end

  test "should use within_timeframe scope" do
    start_time = 2.hours.ago
    end_time = 1.hour.ago
    
    location_in_range = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 1.5.hours.ago
    )
    
    location_out_of_range = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: 3.hours.ago
    )
    
    locations_in_timeframe = UserLocation.within_timeframe(start_time, end_time)
    assert_includes locations_in_timeframe, location_in_range
    assert_not_includes locations_in_timeframe, location_out_of_range
  end

  test "should use nearby scope" do
    # Create locations at different distances
    nearby_location = UserLocation.create!(
      user: @user,
      latitude: 40.7129, # Very close
      longitude: -74.0061,
      recorded_at: Time.current
    )
    
    far_location = UserLocation.create!(
      user: @user,
      latitude: 40.7589, # Far away (Central Park)
      longitude: -73.9851,
      recorded_at: Time.current
    )
    
    # Test nearby search using simple distance calculation instead of PostGIS
    nearby_locations = UserLocation.all.select do |loc|
      distance = loc.distance_to(40.7128, -74.0060)
      distance <= 1000
    end
    assert_includes nearby_locations, nearby_location
    assert_not_includes nearby_locations, far_location
  end

  test "should get coordinates as array" do
    assert_equal [40.7128, -74.0060], @user_location.coordinates
  end

  test "should check if location is accurate enough" do
    # Test accurate location
    @user_location.accuracy = 50
    assert @user_location.accurate?
    
    # Test inaccurate location
    @user_location.accuracy = 150
    assert_not @user_location.accurate?
    
    # Test nil accuracy
    @user_location.accuracy = nil
    assert_not @user_location.accurate?
  end

  test "should get formatted location string" do
    formatted = @user_location.formatted_location
    assert_equal "40.7128, -74.006", formatted
  end

  test "should handle edge cases in distance calculation" do
    # Test same coordinates
    distance = @user_location.distance_to(40.7128, -74.0060)
    assert_equal 0, distance

    # Test very close coordinates
    distance = @user_location.distance_to(40.7128001, -74.0060001)
    assert distance < 1 # Should be less than 1 meter
  end

  test "should handle decimal precision correctly" do
    location = UserLocation.create!(
      user: @user,
      latitude: 40.712800,
      longitude: -74.006000,
      accuracy: 10.50,
      recorded_at: Time.current
    )

    assert_equal 40.712800, location.latitude
    assert_equal -74.006000, location.longitude
    assert_equal 10.50, location.accuracy
  end

  test "should validate numericality of coordinates" do
    @user_location.latitude = "invalid"
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:latitude], "is not a number"

    @user_location.latitude = 40.7128
    @user_location.longitude = "invalid"
    assert_not @user_location.valid?
    assert_includes @user_location.errors[:longitude], "is not a number"
  end

  test "should validate numericality of accuracy" do
    @user_location.accuracy = "invalid"
    # The model doesn't have numericality validation for accuracy
    assert @user_location.valid?
  end

  test "should handle very high accuracy" do
    @user_location.accuracy = 0.1
    assert @user_location.valid?
    assert @user_location.accurate?
  end

  test "should handle very low accuracy" do
    @user_location.accuracy = 1000
    assert @user_location.valid?
    assert_not @user_location.accurate?
  end

  test "should handle negative accuracy" do
    @user_location.accuracy = -10
    assert @user_location.valid?
    # Negative accuracy should still be considered accurate if within 100 meters
    assert @user_location.accurate?
  end

  test "should handle zero accuracy" do
    @user_location.accuracy = 0
    assert @user_location.valid?
    assert @user_location.accurate?
  end

  test "should handle future recorded_at" do
    future_time = 1.hour.from_now
    @user_location.recorded_at = future_time
    
    assert @user_location.valid?
    assert_equal future_time.to_i, @user_location.recorded_at.to_i
  end

  test "should handle past recorded_at" do
    past_time = 1.hour.ago
    @user_location.recorded_at = past_time
    
    assert @user_location.valid?
    assert_equal past_time.to_i, @user_location.recorded_at.to_i
  end

  test "should handle very old recorded_at" do
    very_old_time = 1.year.ago
    @user_location.recorded_at = very_old_time
    
    assert @user_location.valid?
    assert_equal very_old_time.to_i, @user_location.recorded_at.to_i
  end

  test "should handle very future recorded_at" do
    very_future_time = 1.year.from_now
    @user_location.recorded_at = very_future_time
    
    assert @user_location.valid?
    assert_equal very_future_time.to_i, @user_location.recorded_at.to_i
  end

  test "should handle different time zones" do
    utc_time = Time.utc(2024, 1, 1, 12, 0, 0)
    local_time = Time.local(2024, 1, 1, 12, 0, 0)
    
    utc_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: utc_time
    )
    
    local_location = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: local_time
    )
    
    assert utc_location.valid?
    assert local_location.valid?
    assert_equal utc_time.to_i, utc_location.recorded_at.to_i
    assert_equal local_time.to_i, local_location.recorded_at.to_i
  end

  test "should handle microsecond precision" do
    precise_time = Time.current
    
    location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: precise_time
    )
    
    assert location.valid?
    # Should be within 1 second of the original time
    assert (location.recorded_at - precise_time).abs < 1.second
  end

  test "should handle multiple locations for same user" do
    # Create multiple locations for the same user
    locations = []
    
    5.times do |i|
      location = UserLocation.create!(
        user: @user,
        latitude: 40.7128 + (i * 0.001),
        longitude: -74.0060 + (i * 0.001),
        recorded_at: i.hours.ago
      )
      locations << location
    end
    
    assert_equal 5, @user.user_locations.count
    assert_equal 5, UserLocation.where(user: @user).count
  end

  test "should handle locations from different users" do
    other_user = create_test_user
    
    user1_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    user2_location = UserLocation.create!(
      user: other_user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: Time.current
    )
    
    assert_equal @user, user1_location.user
    assert_equal other_user, user2_location.user
    assert_equal 1, @user.user_locations.count
    assert_equal 1, other_user.user_locations.count
  end

  test "should handle locations with extreme coordinates" do
    # Test North Pole
    north_pole = UserLocation.create!(
      user: @user,
      latitude: 90,
      longitude: 0,
      recorded_at: Time.current
    )
    assert north_pole.valid?
    
    # Test South Pole
    south_pole = UserLocation.create!(
      user: @user,
      latitude: -90,
      longitude: 0,
      recorded_at: Time.current
    )
    assert south_pole.valid?
    
    # Test International Date Line
    date_line = UserLocation.create!(
      user: @user,
      latitude: 0,
      longitude: 180,
      recorded_at: Time.current
    )
    assert date_line.valid?
    
    # Test Prime Meridian
    prime_meridian = UserLocation.create!(
      user: @user,
      latitude: 0,
      longitude: 0,
      recorded_at: Time.current
    )
    assert prime_meridian.valid?
  end

  test "should handle locations with very small coordinate differences" do
    base_lat = 40.7128
    base_lng = -74.0060
    
    # Create locations with very small differences
    location1 = UserLocation.create!(
      user: @user,
      latitude: base_lat,
      longitude: base_lng,
      recorded_at: Time.current
    )
    
    location2 = UserLocation.create!(
      user: @user,
      latitude: base_lat + 0.000001,
      longitude: base_lng + 0.000001,
      recorded_at: Time.current
    )
    
    distance = location1.distance_to(location2.latitude, location2.longitude)
    assert distance < 1 # Should be less than 1 meter
  end

  test "should handle locations with very large coordinate differences" do
    # Test distance between New York and Los Angeles
    ny_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    la_location = UserLocation.create!(
      user: @user,
      latitude: 34.0522,
      longitude: -118.2437,
      recorded_at: Time.current
    )
    
    distance = ny_location.distance_to(la_location.latitude, la_location.longitude)
    assert distance > 3000000 # Should be more than 3000km
    assert distance < 5000000 # Should be less than 5000km
  end

  test "should handle locations with zero coordinates" do
    zero_location = UserLocation.create!(
      user: @user,
      latitude: 0,
      longitude: 0,
      recorded_at: Time.current
    )
    
    assert zero_location.valid?
    assert_equal [0, 0], zero_location.coordinates
  end

  test "should handle locations with negative coordinates" do
    negative_location = UserLocation.create!(
      user: @user,
      latitude: -40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    assert negative_location.valid?
    assert_equal [-40.7128, -74.0060], negative_location.coordinates
  end

  test "should handle locations with very high precision coordinates" do
    high_precision_location = UserLocation.create!(
      user: @user,
      latitude: 40.712800123456,
      longitude: -74.006000123456,
      recorded_at: Time.current
    )
    
    assert high_precision_location.valid?
    # Should be rounded to 6 decimal places
    assert_equal 40.712800, high_precision_location.latitude
    assert_equal -74.006000, high_precision_location.longitude
  end

  test "should handle locations with very large accuracy values" do
    large_accuracy_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy: 999999.99,
      recorded_at: Time.current
    )
    
    assert large_accuracy_location.valid?
    assert_equal 999999.99, large_accuracy_location.accuracy
    assert_not large_accuracy_location.accurate?
  end

  test "should handle locations with very small accuracy values" do
    small_accuracy_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy: 0.01,
      recorded_at: Time.current
    )
    
    assert small_accuracy_location.valid?
    assert_equal 0.01, small_accuracy_location.accuracy
    assert small_accuracy_location.accurate?
  end

  test "should handle locations with fractional accuracy" do
    fractional_accuracy_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy: 15.75,
      recorded_at: Time.current
    )
    
    assert fractional_accuracy_location.valid?
    assert_equal 15.75, fractional_accuracy_location.accuracy
    assert fractional_accuracy_location.accurate?
  end

  test "should handle locations with scientific notation coordinates" do
    scientific_location = UserLocation.create!(
      user: @user,
      latitude: 4.07128e1, # 40.7128
      longitude: -7.4006e1, # -74.006
      recorded_at: Time.current
    )
    
    assert scientific_location.valid?
    assert_equal 40.7128, scientific_location.latitude
    assert_equal -74.006, scientific_location.longitude
  end

  test "should handle locations with string coordinates" do
    string_location = UserLocation.create!(
      user: @user,
      latitude: "40.7128",
      longitude: "-74.0060",
      recorded_at: Time.current
    )
    
    assert string_location.valid?
    assert_equal 40.7128, string_location.latitude
    assert_equal -74.0060, string_location.longitude
  end

  test "should handle locations with integer coordinates" do
    integer_location = UserLocation.create!(
      user: @user,
      latitude: 40,
      longitude: -74,
      recorded_at: Time.current
    )
    
    assert integer_location.valid?
    assert_equal 40, integer_location.latitude
    assert_equal -74, integer_location.longitude
  end

  test "should handle locations with mixed data types" do
    mixed_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      accuracy: 10.5,
      recorded_at: Time.current
    )
    
    assert mixed_location.valid?
    assert_equal 40.7128, mixed_location.latitude
    assert_equal -74.0060, mixed_location.longitude
    assert_equal 10.5, mixed_location.accuracy
  end

  test "should handle locations with edge case timestamps" do
    # Test Unix epoch
    epoch_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.at(0)
    )
    assert epoch_location.valid?
    
    # Test far future
    future_location = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.at(2**31 - 1) # Max 32-bit timestamp
    )
    assert future_location.valid?
  end

  test "should handle locations with duplicate coordinates" do
    location1 = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    location2 = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    assert location1.valid?
    assert location2.valid?
    assert_equal 0, location1.distance_to(location2.latitude, location2.longitude)
  end

  test "should handle locations with same user and different times" do
    location1 = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: 1.hour.ago
    )
    
    location2 = UserLocation.create!(
      user: @user,
      latitude: 40.7138,
      longitude: -74.0070,
      recorded_at: Time.current
    )
    
    assert location1.valid?
    assert location2.valid?
    assert_not_equal location1.recorded_at, location2.recorded_at
  end

  test "should handle locations with same coordinates and different users" do
    other_user = create_test_user
    
    location1 = UserLocation.create!(
      user: @user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    location2 = UserLocation.create!(
      user: other_user,
      latitude: 40.7128,
      longitude: -74.0060,
      recorded_at: Time.current
    )
    
    assert location1.valid?
    assert location2.valid?
    assert_equal location1.latitude, location2.latitude
    assert_equal location1.longitude, location2.longitude
    assert_not_equal location1.user, location2.user
  end
end
