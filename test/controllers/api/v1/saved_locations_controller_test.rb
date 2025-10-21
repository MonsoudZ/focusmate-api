require "test_helper"

class Api::V1::SavedLocationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @location = SavedLocation.create!(
      user: @user,
      name: "Home",
      latitude: 40.7128,
      longitude: -74.0060,
      radius_meters: 100,
      address: "123 Main St, New York, NY"
    )
    
    @other_location = SavedLocation.create!(
      user: @other_user,
      name: "Other User's Home",
      latitude: 34.0522,
      longitude: -118.2437,
      radius_meters: 200,
      address: "456 Oak Ave, Los Angeles, CA"
    )
    
    @user_headers = auth_headers(@user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Index tests
  test "should get all saved locations for user" do
    get "/api/v1/saved_locations", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @location.id, json.first["id"]
    assert_equal "Home", json.first["name"]
    assert_equal 40.7128, json.first["latitude"]
    assert_equal -74.0060, json.first["longitude"]
    assert_equal 100, json.first["radius_meters"]
    assert_equal "123 Main St, New York, NY", json.first["address"]
  end

  test "should not get locations from other users" do
    get "/api/v1/saved_locations", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @location.id, json.first["id"]
    assert_not_includes json.map { |loc| loc["id"] }, @other_location.id
  end

  test "should not get saved locations without authentication" do
    get "/api/v1/saved_locations"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle empty locations list" do
    new_user = create_test_user(email: "new_user_#{SecureRandom.hex(4)}@example.com")
    new_user_headers = auth_headers(new_user)
    
    get "/api/v1/saved_locations", headers: new_user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 0, json.length
  end

  test "should include location details" do
    get "/api/v1/saved_locations", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    
    location = json.first
    assert_includes location.keys, "id"
    assert_includes location.keys, "name"
    assert_includes location.keys, "latitude"
    assert_includes location.keys, "longitude"
    assert_includes location.keys, "radius_meters"
    assert_includes location.keys, "address"
    assert_includes location.keys, "created_at"
    assert_includes location.keys, "updated_at"
  end

  # Show tests
  test "should show location details" do
    get "/api/v1/saved_locations/#{@location.id}", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name", "latitude", "longitude", "radius_meters", "address"])
    
    assert_equal @location.id, json["id"]
    assert_equal "Home", json["name"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
    assert_equal 100, json["radius_meters"]
    assert_equal "123 Main St, New York, NY", json["address"]
  end

  test "should not show location from other user" do
    get "/api/v1/saved_locations/#{@other_location.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Saved location not found")
  end

  test "should not show location without authentication" do
    get "/api/v1/saved_locations/#{@location.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Create tests
  test "should create saved location with coordinates" do
    location_params = {
      saved_location: {
        name: "Office",
        latitude: 40.7589,
        longitude: -73.9851,
        radius_meters: 150,
        address: "456 Broadway, New York, NY"
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "latitude", "longitude", "radius_meters", "address"])
    
    assert_equal "Office", json["name"]
    assert_equal 40.7589, json["latitude"]
    assert_equal -73.9851, json["longitude"]
    assert_equal 150, json["radius_meters"]
    assert_equal "456 Broadway, New York, NY", json["address"]
  end

  test "should create with address (geocode to coordinates)" do
    location_params = {
      saved_location: {
        name: "Central Park",
        address: "Central Park, New York, NY",
        latitude: 40.7829,  # Central Park coordinates
        longitude: -73.9654,
        radius_meters: 500
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "address", "radius_meters"])
    
    assert_equal "Central Park", json["name"]
    assert_equal "Central Park, New York, NY", json["address"]
    assert_equal 500, json["radius_meters"]
  end

  test "should validate latitude/longitude bounds" do
    # Test invalid latitude (outside -90 to 90 range)
    location_params = {
      saved_location: {
        name: "Invalid Lat",
        latitude: 91.0,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response)
    assert_includes json["errors"], "Latitude must be less than or equal to 90"
  end

  test "should validate radius_meters" do
    # Test negative radius
    location_params = {
      saved_location: {
        name: "Invalid Radius",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: -50
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response)
    assert_includes json["errors"], "Radius meters must be greater than 0"
  end

  test "should require name" do
    location_params = {
      saved_location: {
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response)
    assert_includes json["errors"], "Name can't be blank"
  end

  test "should not create location without authentication" do
    location_params = {
      saved_location: {
        name: "No Auth Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle location with only coordinates" do
    location_params = {
      saved_location: {
        name: "Coordinates Only",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "latitude", "longitude", "radius_meters"])
    
    assert_equal "Coordinates Only", json["name"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
    assert_equal 100, json["radius_meters"]
  end

  test "should handle location with only address" do
    location_params = {
      saved_location: {
        name: "Address Only",
        address: "Times Square, New York, NY",
        latitude: 40.7580,  # Times Square coordinates
        longitude: -73.9855,
        radius_meters: 200
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "address", "radius_meters"])
    
    assert_equal "Address Only", json["name"]
    assert_equal "Times Square, New York, NY", json["address"]
    assert_equal 200, json["radius_meters"]
  end

  # Update tests
  test "should update saved location" do
    update_params = {
      saved_location: {
        name: "Updated Home",
        latitude: 40.7589,
        longitude: -73.9851,
        radius_meters: 200,
        address: "Updated Address, New York, NY"
      }
    }
    
    patch "/api/v1/saved_locations/#{@location.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name", "latitude", "longitude", "radius_meters", "address"])
    
    assert_equal "Updated Home", json["name"]
    assert_equal 40.7589, json["latitude"]
    assert_equal -73.9851, json["longitude"]
    assert_equal 200, json["radius_meters"]
    assert_equal "Updated Address, New York, NY", json["address"]
  end

  test "should not allow updating other user's locations" do
    update_params = {
      saved_location: {
        name: "Hacked Location",
        latitude: 40.7589,
        longitude: -73.9851,
        radius_meters: 200
      }
    }
    
    patch "/api/v1/saved_locations/#{@other_location.id}", params: update_params, headers: @user_headers
    
    assert_error_response(response, :not_found, "Resource not found not found")
  end

  test "should not update location without authentication" do
    update_params = {
      saved_location: {
        name: "No Auth Update",
        latitude: 40.7589,
        longitude: -73.9851,
        radius_meters: 200
      }
    }
    
    patch "/api/v1/saved_locations/#{@location.id}", params: update_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle partial updates" do
    update_params = {
      saved_location: {
        name: "Partially Updated"
      }
    }
    
    patch "/api/v1/saved_locations/#{@location.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "name"])
    
    assert_equal "Partially Updated", json["name"]
    # Other fields should remain unchanged
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
  end

  test "should handle invalid updates" do
    update_params = {
      saved_location: {
        name: "",  # Empty name should be invalid
        latitude: 91.0,  # Invalid latitude
        radius_meters: -50  # Invalid radius
      }
    }
    
    patch "/api/v1/saved_locations/#{@location.id}", params: update_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response)
    assert_includes json["errors"], "Name can't be blank"
  end

  # Delete tests
  test "should delete saved location" do
    delete "/api/v1/saved_locations/#{@location.id}", headers: @user_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      SavedLocation.find(@location.id)
    end
  end

  test "should not affect tasks using this location" do
    # Create a task that uses this location
    task = Task.create!(
      list: create_test_list(@user),
      creator: @user,
      title: "Task at Home",
      note: "Task that uses the home location",
      due_at: 1.day.from_now,
      strict_mode: false,
      location_based: true,
      location_latitude: @location.latitude,
      location_longitude: @location.longitude,
      location_radius_meters: @location.radius_meters,
      location_name: @location.name
    )
    
    delete "/api/v1/saved_locations/#{@location.id}", headers: @user_headers
    
    assert_response :no_content
    
    # Task should still exist
    task.reload
    assert_equal "Task at Home", task.title
    assert_equal @location.latitude, task.location_latitude
    assert_equal @location.longitude, task.location_longitude
    assert_equal @location.radius_meters, task.location_radius_meters
    assert_equal @location.name, task.location_name
  end

  test "should not delete location from other user" do
    delete "/api/v1/saved_locations/#{@other_location.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Resource not found not found")
    
    # Location should still exist
    @other_location.reload
    assert_equal "Other User's Home", @other_location.name
  end

  test "should not delete location without authentication" do
    delete "/api/v1/saved_locations/#{@location.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
    
    # Location should still exist
    @location.reload
    assert_equal "Home", @location.name
  end

  # Edge cases
  test "should handle malformed JSON" do
    patch "/api/v1/saved_locations/#{@location.id}", 
          params: "invalid json",
          headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    patch "/api/v1/saved_locations/#{@location.id}", params: {}, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id"])
    assert_equal @location.id, json["id"]
  end

  test "should handle very long location names" do
    long_name = "A" * 1000
    
    location_params = {
      saved_location: {
        name: long_name,
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response)
    assert_includes json["errors"], "Name is too long (maximum is 255 characters)"
  end

  test "should handle special characters in location name" do
    location_params = {
      saved_location: {
        name: "Location with Special Chars: !@#$%^&*()",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    
    assert_equal "Location with Special Chars: !@#$%^&*()", json["name"]
  end

  test "should handle unicode characters in location name" do
    location_params = {
      saved_location: {
        name: "Unicode Location: 🏠🏢🏪",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name"])
    
    assert_equal "Unicode Location: 🏠🏢🏪", json["name"]
  end

  test "should handle very large radius values" do
    location_params = {
      saved_location: {
        name: "Large Radius Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 10000  # 10km radius (max allowed)
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "radius_meters"])
    
    assert_equal 10000, json["radius_meters"]
  end

  test "should handle very small radius values" do
    location_params = {
      saved_location: {
        name: "Small Radius Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 1  # 1 meter radius
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "radius_meters"])
    
    assert_equal 1, json["radius_meters"]
  end

  test "should handle extreme latitude values" do
    # Test North Pole
    location_params = {
      saved_location: {
        name: "North Pole",
        latitude: 90.0,
        longitude: 0.0,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "latitude", "longitude"])
    
    assert_equal 90.0, json["latitude"]
    assert_equal 0.0, json["longitude"]
  end

  test "should handle extreme longitude values" do
    # Test International Date Line
    location_params = {
      saved_location: {
        name: "Date Line",
        latitude: 0.0,
        longitude: 180.0,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "latitude", "longitude"])
    
    assert_equal 0.0, json["latitude"]
    assert_equal 180.0, json["longitude"]
  end

  test "should handle concurrent location creation" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        location_params = {
          saved_location: {
            name: "Concurrent Location #{i}",
            latitude: 40.7128 + (i * 0.001),
            longitude: -74.0060 + (i * 0.001),
            radius_meters: 100
          }
        }
        
        post "/api/v1/saved_locations", params: location_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different coordinates
    assert true
  end

  test "should handle concurrent location updates" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        update_params = {
          saved_location: {
            name: "Concurrent Update #{i}",
            radius_meters: 100 + i
          }
        }
        
        patch "/api/v1/saved_locations/#{@location.id}", params: update_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle location with very long address" do
    long_address = "A" * 2000
    
    location_params = {
      saved_location: {
        name: "Long Address Location",
        address: long_address,
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "address"])
    
    assert_equal long_address, json["address"]
  end

  test "should handle location with empty address" do
    location_params = {
      saved_location: {
        name: "No Address Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100,
        address: ""
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "latitude", "longitude"])
    
    assert_equal "No Address Location", json["name"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
  end

  test "should handle location with nil address" do
    location_params = {
      saved_location: {
        name: "Nil Address Location",
        latitude: 40.7128,
        longitude: -74.0060,
        radius_meters: 100,
        address: nil
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "name", "latitude", "longitude"])
    
    assert_equal "Nil Address Location", json["name"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
  end

  test "should handle location with zero coordinates" do
    location_params = {
      saved_location: {
        name: "Zero Coordinates",
        latitude: 0.0,
        longitude: 0.0,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "latitude", "longitude"])
    
    assert_equal 0.0, json["latitude"]
    assert_equal 0.0, json["longitude"]
  end

  test "should handle location with decimal precision coordinates" do
    location_params = {
      saved_location: {
        name: "Precise Location",
        latitude: 40.712800123456789,
        longitude: -74.006000987654321,
        radius_meters: 100
      }
    }
    
    post "/api/v1/saved_locations", params: location_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "latitude", "longitude"])
    
    # Should handle precision correctly
    assert_in_delta 40.712800123456789, json["latitude"], 0.000001
    assert_in_delta -74.006000987654321, json["longitude"], 0.000001
  end
end
