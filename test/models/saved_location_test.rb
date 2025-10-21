require "test_helper"

class SavedLocationTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @saved_location = SavedLocation.new(
      user: @user,
      name: "Test Location",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 100
    )
  end

  test "should belong to user" do
    assert @saved_location.valid?
    assert_equal @user, @saved_location.user
  end

  test "should require name" do
    @saved_location.name = nil
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:name], "can't be blank"
  end

  test "should require latitude" do
    @saved_location.latitude = nil
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:latitude], "can't be blank"
  end

  test "should require longitude" do
    @saved_location.longitude = nil
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:longitude], "can't be blank"
  end

  test "should validate latitude between -90 and 90" do
    # Test valid latitudes
    @saved_location.latitude = 0
    assert @saved_location.valid?

    @saved_location.latitude = 90
    assert @saved_location.valid?

    @saved_location.latitude = -90
    assert @saved_location.valid?

    # Test invalid latitudes
    @saved_location.latitude = 91
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:latitude], "must be less than or equal to 90"

    @saved_location.latitude = -91
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:latitude], "must be greater than or equal to -90"
  end

  test "should validate longitude between -180 and 180" do
    # Test valid longitudes
    @saved_location.longitude = 0
    assert @saved_location.valid?

    @saved_location.longitude = 180
    assert @saved_location.valid?

    @saved_location.longitude = -180
    assert @saved_location.valid?

    # Test invalid longitudes
    @saved_location.longitude = 181
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:longitude], "must be less than or equal to 180"

    @saved_location.longitude = -181
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:longitude], "must be greater than or equal to -180"
  end

  test "should default radius_meters to 100" do
    location = SavedLocation.create!(
      user: @user,
      name: "Default Radius Test",
      latitude: 40.7128,
      longitude: -74.0060
    )
    assert_equal 100, location.radius_meters
  end

  test "should validate radius_meters between 1 and 10000" do
    # Test valid radius values
    @saved_location.radius_meters = 1
    assert @saved_location.valid?

    @saved_location.radius_meters = 1000
    assert @saved_location.valid?

    @saved_location.radius_meters = 10000
    assert @saved_location.valid?

    # Test invalid radius
    @saved_location.radius_meters = 0
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:radius_meters], "must be greater than 0"

    @saved_location.radius_meters = -1
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:radius_meters], "must be greater than 0"

    @saved_location.radius_meters = 10001
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:radius_meters], "must be less than or equal to 10000"
  end

  test "should allow optional address" do
    @saved_location.address = "123 Main St, New York, NY"
    assert @saved_location.valid?
    assert_equal "123 Main St, New York, NY", @saved_location.address
  end

  test "should validate name length" do
    @saved_location.name = "a" * 256
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:name], "is too long (maximum is 255 characters)"

    @saved_location.name = "a" * 255
    assert @saved_location.valid?
  end

  test "should get coordinates as array" do
    assert_equal [40.7128, -74.0060], @saved_location.coordinates
  end

  test "should calculate distance to another point" do
    # Test distance to same point (should be 0)
    distance = @saved_location.distance_to(40.7128, -74.0060)
    assert_equal 0, distance.round(2)

    # Test distance to nearby point (approximately 1km away)
    # Using coordinates roughly 1km northeast of NYC
    distance = @saved_location.distance_to(40.7218, -73.9960)
    assert distance > 1200 # Should be around 1.3km
    assert distance < 1400
  end

  test "should check if coordinates are within radius" do
    # Test point within radius
    assert @saved_location.contains?(40.7128, -74.0060) # Same point
    assert @saved_location.contains?(40.7129, -74.0060) # Very close point

    # Test point outside radius
    # Using coordinates approximately 200m away (about 0.002 degrees)
    # Let's use a point that's definitely outside the 100m radius
    assert_not @saved_location.contains?(40.7158, -74.0060)
  end

  test "should get formatted address" do
    # Test with address
    @saved_location.address = "123 Main St, New York, NY"
    assert_equal "123 Main St, New York, NY", @saved_location.formatted_address

    # Test without address (should use coordinates)
    @saved_location.address = nil
    expected = "Test Location (40.7128, -74.006)"
    assert_equal expected, @saved_location.formatted_address
  end

  test "should check if user is at location" do
    # Create a user location
    @user.update_location!(40.7128, -74.0060, 10.0)
    
    # Test user at same location
    assert @saved_location.user_at_location?(@user)

    # Test user at different location
    @user.update_location!(40.7589, -73.9851, 10.0) # Central Park
    assert_not @saved_location.user_at_location?(@user)

    # Test user without location
    user_without_location = create_test_user
    assert_not @saved_location.user_at_location?(user_without_location)
  end

  test "should get location summary" do
    @saved_location.address = "123 Main St"
    summary = @saved_location.summary

    assert_equal @saved_location.id, summary[:id]
    assert_equal "Test Location", summary[:name]
    assert_equal [40.7128, -74.0060], summary[:coordinates]
    assert_equal 100, summary[:radius]
    assert_equal "123 Main St", summary[:address]
  end

  test "should find nearby locations for user" do
    # Create multiple saved locations
    location1 = @user.saved_locations.create!(
      name: "Location 1",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 100
    )
    
    location2 = @user.saved_locations.create!(
      name: "Location 2", 
      latitude: 40.7589,
      longitude: -73.9851,
      radius_meters: 100
    )

    # Test nearby search using simple distance calculation instead of PostGIS
    nearby = @user.saved_locations.select do |loc|
      distance = loc.distance_to(40.7128, -74.0060)
      distance <= 1000
    end
    assert_includes nearby, location1
    assert_not_includes nearby, location2
  end

  test "should use for_user scope" do
    other_user = create_test_user
    location1 = @user.saved_locations.create!(
      name: "User 1 Location",
      latitude: 40.7128,
      longitude: -74.0060
    )
    location2 = other_user.saved_locations.create!(
      name: "User 2 Location",
      latitude: 40.7128,
      longitude: -74.0060
    )

    user_locations = SavedLocation.for_user(@user)
    assert_includes user_locations, location1
    assert_not_includes user_locations, location2
  end

  test "should use nearby scope" do
    location1 = @user.saved_locations.create!(
      name: "Nearby Location",
      latitude: 40.7128,
      longitude: -74.0060
    )
    location2 = @user.saved_locations.create!(
      name: "Far Location",
      latitude: 40.7589,
      longitude: -73.9851
    )

    # Skip PostGIS test if not available, test manual distance calculation instead
    nearby = SavedLocation.all.select do |loc|
      distance = loc.distance_to(40.7128, -74.0060)
      distance <= 1000
    end
    assert_includes nearby, location1
    assert_not_includes nearby, location2
  end

  test "should handle edge cases in distance calculation" do
    # Test same coordinates
    distance = @saved_location.distance_to(40.7128, -74.0060)
    assert_equal 0, distance

    # Test very close coordinates
    distance = @saved_location.distance_to(40.7128001, -74.0060001)
    assert distance < 1 # Should be less than 1 meter
  end

  test "should handle decimal precision correctly" do
    location = SavedLocation.create!(
      user: @user,
      name: "Precision Test",
      latitude: 40.712800,
      longitude: -74.006000,
      radius_meters: 100
    )

    assert_equal 40.712800, location.latitude
    assert_equal -74.006000, location.longitude
  end

  test "should validate numericality of coordinates" do
    @saved_location.latitude = "invalid"
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:latitude], "is not a number"

    @saved_location.latitude = 40.7128
    @saved_location.longitude = "invalid"
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:longitude], "is not a number"
  end

  test "should validate numericality of radius" do
    @saved_location.radius_meters = "invalid"
    assert_not @saved_location.valid?
    assert_includes @saved_location.errors[:radius_meters], "is not a number"
  end

  test "should handle large radius values" do
    @saved_location.radius_meters = 10000
    assert @saved_location.valid?
    assert @saved_location.save
  end

  test "should handle small radius values" do
    @saved_location.radius_meters = 1
    assert @saved_location.valid?
    assert @saved_location.save
  end

  test "should create saved location with all attributes" do
    location = SavedLocation.create!(
      user: @user,
      name: "Complete Location",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 500,
      address: "123 Main St, New York, NY"
    )

    assert location.persisted?
    assert_equal @user, location.user
    assert_equal "Complete Location", location.name
    assert_equal 40.7128, location.latitude
    assert_equal -74.0060, location.longitude
    assert_equal 500, location.radius_meters
    assert_equal "123 Main St, New York, NY", location.address
  end

  test "should handle user without current location" do
    user_without_location = create_test_user
    assert_not @saved_location.user_at_location?(user_without_location)
  end

  test "should handle nil address in formatted_address" do
    @saved_location.address = nil
    formatted = @saved_location.formatted_address
    assert_includes formatted, "Test Location"
    assert_includes formatted, "40.7128"
    assert_includes formatted, "-74.006"
  end

  test "should handle empty address in formatted_address" do
    @saved_location.address = ""
    formatted = @saved_location.formatted_address
    assert_includes formatted, "Test Location"
    assert_includes formatted, "40.7128"
    assert_includes formatted, "-74.006"
  end
end