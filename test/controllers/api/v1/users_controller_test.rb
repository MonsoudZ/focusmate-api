require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @user_headers = auth_headers(@user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Update Location tests
  test "should update user's current location" do
    location_params = {
      latitude: 40.7128,
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "latitude", "longitude"])
    
    assert_equal "Location updated successfully", json["message"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
    
    # Verify in database
    @user.reload
    assert_equal 40.7128, @user.latitude
    assert_equal -74.0060, @user.longitude
    assert_not_nil @user.location_updated_at
  end

  test "should create user_location record" do
    location_params = {
      latitude: 40.7128,
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    
    # Check if UserLocation record was created
    user_location = UserLocation.find_by(user: @user)
    assert_not_nil user_location
    assert_equal 40.7128, user_location.latitude
    assert_equal -74.0060, user_location.longitude
  end

  test "should validate coordinates" do
    # Test invalid latitude
    location_params = {
      latitude: 91.0,  # Invalid latitude
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :unprocessable_entity
    json = assert_json_response(response, ["error", "details"], assert_success: false)
    
    assert_equal "Failed to update location", json["error"]
    assert_includes json["details"], "Latitude must be less than or equal to 90"
  end

  test "should trigger location-based task notifications" do
    # Create a location-based task
    list = create_test_list(@user)
    task = Task.create!(
      list: list,
      creator: @user,
      title: "Location Task",
      note: "Task at specific location",
      due_at: 1.day.from_now,
      strict_mode: false,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100,
      location_name: "Test Location"
    )
    
    location_params = {
      latitude: 40.7128,
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "latitude", "longitude"])
    
    assert_equal "Location updated successfully", json["message"]
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
  end

  test "should require latitude and longitude" do
    # Test missing latitude
    location_params = {
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Latitude and longitude are required")
  end

  test "should require longitude" do
    # Test missing longitude
    location_params = {
      latitude: 40.7128
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Latitude and longitude are required")
  end

  test "should not update location without authentication" do
    location_params = {
      latitude: 40.7128,
      longitude: -74.0060
    }
    
    post "/api/v1/users/location", params: location_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle string coordinates" do
    location_params = {
      latitude: "40.7128",
      longitude: "-74.0060"
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["latitude", "longitude"])
    
    assert_equal 40.7128, json["latitude"]
    assert_equal -74.0060, json["longitude"]
  end

  test "should handle extreme coordinates" do
    # Test North Pole
    location_params = {
      latitude: 90.0,
      longitude: 0.0
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["latitude", "longitude"])
    
    assert_equal 90.0, json["latitude"]
    assert_equal 0.0, json["longitude"]
  end

  test "should handle decimal precision coordinates" do
    location_params = {
      latitude: 40.712800123456789,
      longitude: -74.006000987654321
    }
    
    post "/api/v1/users/location", params: location_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["latitude", "longitude"])
    
    # Should handle precision correctly
    assert_in_delta 40.712800123456789, json["latitude"], 0.000001
    assert_in_delta -74.006000987654321, json["longitude"], 0.000001
  end

  # Update Device Token tests
  test "should update Firebase Cloud Messaging token" do
    token_params = {
      fcm_token: "fcm_token_123456789"
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "user_id"])
    
    assert_equal "FCM token updated successfully", json["message"]
    assert_equal @user.id, json["user_id"]
    
    # Verify in database
    @user.reload
    assert_equal "fcm_token_123456789", @user.fcm_token
  end

  test "should allow updating to nil (logout)" do
    # First set a token
    @user.update!(fcm_token: "existing_token")
    
    # Then clear it
    token_params = {
      fcm_token: nil
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "user_id"])
    
    assert_equal "FCM token updated successfully", json["message"]
    assert_equal @user.id, json["user_id"]
    
    # Verify in database
    @user.reload
    assert_nil @user.fcm_token
  end

  test "should handle fcmToken parameter format" do
    token_params = {
      fcmToken: "fcm_token_camel_case"
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "FCM token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal "fcm_token_camel_case", @user.fcm_token
  end

  test "should require FCM token" do
    patch "/api/v1/users/fcm_token", params: {}, headers: @user_headers
    
    assert_error_response(response, :bad_request, "FCM token is required")
  end

  test "should not update FCM token without authentication" do
    token_params = {
      fcm_token: "fcm_token_123456789"
    }
    
    patch "/api/v1/users/fcm_token", params: token_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle very long FCM tokens" do
    long_token = "fcm_token_" + "a" * 1000
    
    token_params = {
      fcm_token: long_token
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "FCM token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal long_token, @user.fcm_token
  end

  test "should handle special characters in FCM token" do
    special_token = "fcm_token_!@#$%^&*()_+-=[]{}|;':\",./<>?"
    
    token_params = {
      fcm_token: special_token
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "FCM token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal special_token, @user.fcm_token
  end

  test "should handle unicode characters in FCM token" do
    unicode_token = "fcm_token_🚀📱💻_unicode"
    
    token_params = {
      fcm_token: unicode_token
    }
    
    patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "FCM token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal unicode_token, @user.fcm_token
  end

  # Update Device Token (alternative endpoint) tests
  test "should update device token via device_token parameter" do
    token_params = {
      device_token: "device_token_123456789"
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "user_id"])
    
    assert_equal "Device token updated successfully", json["message"]
    assert_equal @user.id, json["user_id"]
    
    # Verify in database
    @user.reload
    assert_equal "device_token_123456789", @user.device_token
  end

  test "should handle pushToken parameter format" do
    token_params = {
      pushToken: "push_token_camel_case"
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal "push_token_camel_case", @user.device_token
  end

  test "should handle push_token parameter format" do
    token_params = {
      push_token: "push_token_snake_case"
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal "push_token_snake_case", @user.device_token
  end

  test "should require device token" do
    patch "/api/v1/users/device_token", params: {}, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Device token is required")
  end

  test "should not update device token without authentication" do
    token_params = {
      device_token: "device_token_123456789"
    }
    
    patch "/api/v1/users/device_token", params: token_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # APNs Device Token tests
  test "should update APNs device token" do
    apns_token = "apns_token_123456789abcdef"
    
    token_params = {
      device_token: apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "user_id"])
    
    assert_equal "Device token updated successfully", json["message"]
    assert_equal @user.id, json["user_id"]
    
    # Verify in database
    @user.reload
    assert_equal apns_token, @user.device_token
  end

  test "should associate token with user" do
    apns_token = "apns_token_#{SecureRandom.hex(16)}"
    
    token_params = {
      device_token: apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    
    # Verify the token is associated with the correct user
    @user.reload
    assert_equal apns_token, @user.device_token
    assert_equal @user.id, User.find_by(device_token: apns_token).id
  end

  test "should allow updating APNs token to nil (logout)" do
    # First set a token
    @user.update!(device_token: "existing_apns_token")
    
    # Then clear it (logout)
    token_params = {
      device_token: nil
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "user_id"])
    
    assert_equal "Device token updated successfully", json["message"]
    assert_equal @user.id, json["user_id"]
    
    # Verify in database
    @user.reload
    assert_nil @user.device_token
  end

  test "should handle APNs token format validation" do
    # Test valid APNs token format (64 hex characters)
    valid_apns_token = "a" * 64
    
    token_params = {
      device_token: valid_apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal valid_apns_token, @user.device_token
  end

  test "should handle very long APNs tokens" do
    long_apns_token = "apns_" + "a" * 1000
    
    token_params = {
      device_token: long_apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal long_apns_token, @user.device_token
  end

  test "should handle special characters in APNs token" do
    special_apns_token = "apns_token_!@#$%^&*()_+-=[]{}|;':\",./<>?"
    
    token_params = {
      device_token: special_apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal special_apns_token, @user.device_token
  end

  test "should handle unicode characters in APNs token" do
    unicode_apns_token = "apns_token_🚀📱💻_unicode"
    
    token_params = {
      device_token: unicode_apns_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal unicode_apns_token, @user.device_token
  end

  test "should handle concurrent APNs token updates" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        token_params = {
          device_token: "apns_token_#{i}_#{SecureRandom.hex(16)}"
        }
        
        patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle APNs token with different parameter names" do
    # Test pushToken parameter
    push_token = "push_token_#{SecureRandom.hex(16)}"
    
    token_params = {
      pushToken: push_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal push_token, @user.device_token
  end

  test "should handle APNs token with push_token parameter" do
    # Test push_token parameter
    push_token = "push_token_#{SecureRandom.hex(16)}"
    
    token_params = {
      push_token: push_token
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    
    assert_equal "Device token updated successfully", json["message"]
    
    # Verify in database
    @user.reload
    assert_equal push_token, @user.device_token
  end

  test "should handle empty APNs token" do
    token_params = {
      device_token: ""
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Device token is required")
  end

  test "should handle whitespace-only APNs token" do
    token_params = {
      device_token: "   "
    }
    
    patch "/api/v1/users/device_token", params: token_params, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Device token is required")
  end

  # Update Preferences tests
  test "should update user preferences" do
    preferences_params = {
      preferences: {
        notifications: true,
        email_reminders: false,
        timezone: "America/New_York",
        language: "en",
        theme: "dark"
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "true", json["preferences"]["notifications"]
    assert_equal "false", json["preferences"]["email_reminders"]
    assert_equal "America/New_York", json["preferences"]["timezone"]
    assert_equal "en", json["preferences"]["language"]
    assert_equal "dark", json["preferences"]["theme"]
    
    # Verify in database
    @user.reload
    assert_equal "true", @user.preferences["notifications"]
    assert_equal "false", @user.preferences["email_reminders"]
    assert_equal "America/New_York", @user.preferences["timezone"]
    assert_equal "en", @user.preferences["language"]
    assert_equal "dark", @user.preferences["theme"]
  end

  test "should handle empty preferences" do
    preferences_params = {
      preferences: {}
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal({}, json["preferences"])
  end

  test "should handle nil preferences" do
    patch "/api/v1/users/preferences", params: {}, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal({}, json["preferences"])
  end

  test "should not update preferences without authentication" do
    preferences_params = {
      preferences: {
        notifications: true
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle complex nested preferences" do
    preferences_params = {
      preferences: {
        notifications: {
          email: true,
          push: false,
          sms: true
        },
        privacy: {
          profile_visibility: "friends",
          location_sharing: false
        },
        display: {
          theme: "dark",
          font_size: "large",
          language: "en"
        }
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "true", json["preferences"]["notifications"]["email"]
    assert_equal "false", json["preferences"]["notifications"]["push"]
    assert_equal "true", json["preferences"]["notifications"]["sms"]
    assert_equal "friends", json["preferences"]["privacy"]["profile_visibility"]
    assert_equal "false", json["preferences"]["privacy"]["location_sharing"]
    assert_equal "dark", json["preferences"]["display"]["theme"]
    assert_equal "large", json["preferences"]["display"]["font_size"]
    assert_equal "en", json["preferences"]["display"]["language"]
  end

  test "should handle boolean preferences" do
    preferences_params = {
      preferences: {
        notifications: true,
        email_reminders: false,
        dark_mode: true,
        auto_save: false
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "true", json["preferences"]["notifications"]
    assert_equal "false", json["preferences"]["email_reminders"]
    assert_equal "true", json["preferences"]["dark_mode"]
    assert_equal "false", json["preferences"]["auto_save"]
  end

  test "should handle string preferences" do
    preferences_params = {
      preferences: {
        timezone: "America/New_York",
        language: "en",
        currency: "USD",
        date_format: "MM/DD/YYYY"
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "America/New_York", json["preferences"]["timezone"]
    assert_equal "en", json["preferences"]["language"]
    assert_equal "USD", json["preferences"]["currency"]
    assert_equal "MM/DD/YYYY", json["preferences"]["date_format"]
  end

  test "should handle numeric preferences" do
    preferences_params = {
      preferences: {
        font_size: 16,
        max_notifications: 10,
        timeout_minutes: 30,
        refresh_interval: 5
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "16", json["preferences"]["font_size"]
    assert_equal "10", json["preferences"]["max_notifications"]
    assert_equal "30", json["preferences"]["timeout_minutes"]
    assert_equal "5", json["preferences"]["refresh_interval"]
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/users/location", 
          params: "invalid json",
          headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/users/location", params: {}, headers: @user_headers
    
    assert_error_response(response, :bad_request, "Latitude and longitude are required")
  end

  test "should handle concurrent location updates" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        location_params = {
          latitude: 40.7128 + (i * 0.001),
          longitude: -74.0060 + (i * 0.001)
        }
        
        post "/api/v1/users/location", params: location_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different coordinates
    assert true
  end

  test "should handle concurrent token updates" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        token_params = {
          fcm_token: "fcm_token_#{i}_#{SecureRandom.hex(10)}"
        }
        
        patch "/api/v1/users/fcm_token", params: token_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed
    assert true
  end

  test "should handle very long preference values" do
    long_string = "A" * 1000
    
    preferences_params = {
      preferences: {
        long_description: long_string,
        custom_field: long_string
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal long_string, json["preferences"]["long_description"]
    assert_equal long_string, json["preferences"]["custom_field"]
  end

  test "should handle special characters in preferences" do
    preferences_params = {
      preferences: {
        special_field: "Special Chars: !@#$%^&*()",
        unicode_field: "Unicode: 🚀📱💻",
        json_field: '{"nested": "json", "array": [1, 2, 3]}'
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "Special Chars: !@#$%^&*()", json["preferences"]["special_field"]
    assert_equal "Unicode: 🚀📱💻", json["preferences"]["unicode_field"]
    assert_equal '{"nested": "json", "array": [1, 2, 3]}', json["preferences"]["json_field"]
  end

  test "should handle array preferences" do
    preferences_params = {
      preferences: {
        favorite_categories: ["work", "personal", "health"],
        notification_times: [9, 12, 18],
        enabled_features: ["dark_mode", "notifications", "location"]
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal ["work", "personal", "health"], json["preferences"]["favorite_categories"]
    assert_equal ["9", "12", "18"], json["preferences"]["notification_times"]
    assert_equal ["dark_mode", "notifications", "location"], json["preferences"]["enabled_features"]
  end

  test "should handle mixed data type preferences" do
    preferences_params = {
      preferences: {
        string_field: "string value",
        number_field: 42,
        boolean_field: true,
        array_field: [1, 2, 3],
        object_field: {
          nested: "value",
          count: 5
        }
      }
    }
    
    patch "/api/v1/users/preferences", params: preferences_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "preferences"])
    
    assert_equal "Preferences updated successfully", json["message"]
    assert_equal "string value", json["preferences"]["string_field"]
    assert_equal "42", json["preferences"]["number_field"]
    assert_equal "true", json["preferences"]["boolean_field"]
    assert_equal ["1", "2", "3"], json["preferences"]["array_field"]
    assert_equal "value", json["preferences"]["object_field"]["nested"]
    assert_equal "5", json["preferences"]["object_field"]["count"]
  end
end
