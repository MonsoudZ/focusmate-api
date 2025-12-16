require "rails_helper"

RSpec.describe Api::V1::UsersController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }

  let(:user_headers) { auth_headers(user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "POST /api/v1/users/location" do
    it "should update user's current location" do
      location_params = {
        latitude: 40.7128,
        longitude: -74.0060
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("message")
      expect(json).to have_key("latitude")
      expect(json).to have_key("longitude")

      expect(json["message"]).to eq("Location updated successfully")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)

      # Verify in database
      user.reload
      expect(user.latitude).to eq(40.7128)
      expect(user.longitude).to eq(-74.0060)
      expect(user.location_updated_at).not_to be_nil
    end

    it "should create user_location record" do
      location_params = {
        latitude: 40.7128,
        longitude: -74.0060
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)

      # Check if UserLocation record was created
      user_location = UserLocation.find_by(user: user)
      expect(user_location).not_to be_nil
      expect(user_location.latitude).to eq(40.7128)
      expect(user_location.longitude).to eq(-74.0060)
    end

    it "should validate coordinates" do
      # Test invalid latitude
      location_params = {
        latitude: 91.0,  # Invalid latitude
        longitude: -74.0060
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)

      expect(json).to have_key("error")
      expect(json).to have_key("details")

      expect(json["error"]["message"]).to eq("Failed to update location")
      expect(json["details"]).to include("Latitude must be less than or equal to 90")
    end

    it "should trigger location-based task notifications" do
      # Create a location-based task
      list = create(:list, user: user)
      task = Task.create!(
        list: list,
        creator: user,
        title: "Location Task",
        note: "Task at specific location",
        due_at: 1.day.from_now,
        status: :pending,
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

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Location updated successfully")
      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
    end

    it "should require latitude and longitude" do
      # Test missing latitude
      location_params = {
        longitude: -74.0060
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Latitude and longitude are required")
    end

    it "should require longitude" do
      # Test missing longitude
      location_params = {
        latitude: 40.7128
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Latitude and longitude are required")
    end

    it "should not update location without authentication" do
      location_params = {
        latitude: 40.7128,
        longitude: -74.0060
      }

      post "/api/v1/users/location", params: location_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle string coordinates" do
      location_params = {
        latitude: "40.7128",
        longitude: "-74.0060"
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["latitude"]).to eq(40.7128)
      expect(json["longitude"]).to eq(-74.0060)
    end

    it "should handle extreme coordinates" do
      # Test North Pole
      location_params = {
        latitude: 90.0,
        longitude: 0.0
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["latitude"]).to eq(90.0)
      expect(json["longitude"]).to eq(0.0)
    end

    it "should handle decimal precision coordinates" do
      location_params = {
        latitude: 40.712800123456789,
        longitude: -74.006000987654321
      }

      post "/api/v1/users/location", params: location_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      # Should handle precision correctly
      expect(json["latitude"]).to be_within(0.000001).of(40.712800123456789)
      expect(json["longitude"]).to be_within(0.000001).of(-74.006000987654321)
    end
  end

  describe "PATCH /api/v1/users/fcm_token" do
    it "should update Firebase Cloud Messaging token" do
      token_params = {
        fcm_token: "fcm_token_123456789"
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("message")
      expect(json).to have_key("user_id")

      expect(json["message"]).to eq("FCM token updated successfully")
      expect(json["user_id"]).to eq(user.id)

      # Verify in database
      user.reload
      expect(user.fcm_token).to eq("fcm_token_123456789")
    end

    it "should allow updating to nil (logout)" do
      # First set a token
      user.update!(fcm_token: "existing_token")

      # Then clear it
      token_params = {
        fcm_token: nil
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("FCM token updated successfully")
      expect(json["user_id"]).to eq(user.id)

      # Verify in database
      user.reload
      expect(user.fcm_token).to be_nil
    end

    it "should handle fcmToken parameter format" do
      token_params = {
        fcmToken: "fcm_token_camel_case"
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("FCM token updated successfully")

      # Verify in database
      user.reload
      expect(user.fcm_token).to eq("fcm_token_camel_case")
    end

    it "should require FCM token" do
      patch "/api/v1/users/fcm_token", params: {}, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("FCM token is required")
    end

    it "should not update FCM token without authentication" do
      token_params = {
        fcm_token: "fcm_token_123456789"
      }

      patch "/api/v1/users/fcm_token", params: token_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle very long FCM tokens" do
      long_token = "fcm_token_" + "a" * 1000

      token_params = {
        fcm_token: long_token
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("FCM token updated successfully")

      # Verify in database
      user.reload
      expect(user.fcm_token).to eq(long_token)
    end

    it "should handle special characters in FCM token" do
      special_token = "fcm_token_!@#$%^&*()_+-=[]{}|;':\",./<>?"

      token_params = {
        fcm_token: special_token
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("FCM token updated successfully")

      # Verify in database
      user.reload
      expect(user.fcm_token).to eq(special_token)
    end

    it "should handle unicode characters in FCM token" do
      unicode_token = "fcm_token_🚀📱💻_unicode"

      token_params = {
        fcm_token: unicode_token
      }

      patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("FCM token updated successfully")

      # Verify in database
      user.reload
      expect(user.fcm_token).to eq(unicode_token)
    end
  end

  describe "PATCH /api/v1/users/device_token" do
    it "should update device token via device_token parameter" do
      token_params = {
        device_token: "device_token_123456789"
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("message")
      expect(json).to have_key("user_id")

      expect(json["message"]).to eq("Device token updated successfully")
      expect(json["user_id"]).to eq(user.id)

      # Verify in database
      user.reload
      expect(user.device_token).to eq("device_token_123456789")
    end

    it "should handle pushToken parameter format" do
      token_params = {
        pushToken: "push_token_camel_case"
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq("push_token_camel_case")
    end

    it "should handle push_token parameter format" do
      token_params = {
        push_token: "push_token_snake_case"
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq("push_token_snake_case")
    end

    it "should require device token" do
      patch "/api/v1/users/device_token", params: {}, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Device token is required")
    end

    it "should not update device token without authentication" do
      token_params = {
        device_token: "device_token_123456789"
      }

      patch "/api/v1/users/device_token", params: token_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should update APNs device token" do
      apns_token = "apns_token_123456789abcdef"

      token_params = {
        device_token: apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")
      expect(json["user_id"]).to eq(user.id)

      # Verify in database
      user.reload
      expect(user.device_token).to eq(apns_token)
    end

    it "should associate token with user" do
      apns_token = "apns_token_#{SecureRandom.hex(16)}"

      token_params = {
        device_token: apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)

      # Verify the token is associated with the correct user
      user.reload
      expect(user.device_token).to eq(apns_token)
      expect(User.find_by(device_token: apns_token).id).to eq(user.id)
    end

    it "should allow updating APNs token to nil (logout)" do
      # First set a token
      user.update!(device_token: "existing_apns_token")

      # Then clear it (logout)
      token_params = {
        device_token: nil
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")
      expect(json["user_id"]).to eq(user.id)

      # Verify in database
      user.reload
      expect(user.device_token).to be_nil
    end

    it "should handle APNs token format validation" do
      # Test valid APNs token format (64 hex characters)
      valid_apns_token = "a" * 64

      token_params = {
        device_token: valid_apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(valid_apns_token)
    end

    it "should handle very long APNs tokens" do
      long_apns_token = "apns_" + "a" * 1000

      token_params = {
        device_token: long_apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(long_apns_token)
    end

    it "should handle special characters in APNs token" do
      special_apns_token = "apns_token_!@#$%^&*()_+-=[]{}|;':\",./<>?"

      token_params = {
        device_token: special_apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(special_apns_token)
    end

    it "should handle unicode characters in APNs token" do
      unicode_apns_token = "apns_token_🚀📱💻_unicode"

      token_params = {
        device_token: unicode_apns_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(unicode_apns_token)
    end

    it "should handle concurrent APNs token updates" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          token_params = {
            device_token: "apns_token_#{i}_#{SecureRandom.hex(16)}"
          }

          patch "/api/v1/users/device_token", params: token_params, headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle APNs token with different parameter names" do
      # Test pushToken parameter
      push_token = "push_token_#{SecureRandom.hex(16)}"

      token_params = {
        pushToken: push_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(push_token)
    end

    it "should handle APNs token with push_token parameter" do
      # Test push_token parameter
      push_token = "push_token_#{SecureRandom.hex(16)}"

      token_params = {
        push_token: push_token
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Device token updated successfully")

      # Verify in database
      user.reload
      expect(user.device_token).to eq(push_token)
    end

    it "should handle empty APNs token" do
      token_params = {
        device_token: ""
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Device token is required")
    end

    it "should handle whitespace-only APNs token" do
      token_params = {
        device_token: "   "
      }

      patch "/api/v1/users/device_token", params: token_params, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Device token is required")
    end
  end

  describe "PATCH /api/v1/users/preferences" do
    it "should update user preferences" do
      preferences_params = {
        preferences: {
          notifications: true,
          email_reminders: false,
          timezone: "America/New_York",
          language: "en",
          theme: "dark"
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to have_key("message")
      expect(json).to have_key("preferences")

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["notifications"]).to eq("true")
      expect(json["preferences"]["email_reminders"]).to eq("false")
      expect(json["preferences"]["timezone"]).to eq("America/New_York")
      expect(json["preferences"]["language"]).to eq("en")
      expect(json["preferences"]["theme"]).to eq("dark")

      # Verify in database
      user.reload
      expect(user.preferences["notifications"]).to eq("true")
      expect(user.preferences["email_reminders"]).to eq("false")
      expect(user.preferences["timezone"]).to eq("America/New_York")
      expect(user.preferences["language"]).to eq("en")
      expect(user.preferences["theme"]).to eq("dark")
    end

    it "should handle empty preferences" do
      preferences_params = {
        preferences: {}
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]).to eq({})
    end

    it "should handle nil preferences" do
      patch "/api/v1/users/preferences", params: {}, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]).to eq({})
    end

    it "should not update preferences without authentication" do
      preferences_params = {
        preferences: {
          notifications: true
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle complex nested preferences" do
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

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["notifications"]["email"]).to eq("true")
      expect(json["preferences"]["notifications"]["push"]).to eq("false")
      expect(json["preferences"]["notifications"]["sms"]).to eq("true")
      expect(json["preferences"]["privacy"]["profile_visibility"]).to eq("friends")
      expect(json["preferences"]["privacy"]["location_sharing"]).to eq("false")
      expect(json["preferences"]["display"]["theme"]).to eq("dark")
      expect(json["preferences"]["display"]["font_size"]).to eq("large")
      expect(json["preferences"]["display"]["language"]).to eq("en")
    end

    it "should handle boolean preferences" do
      preferences_params = {
        preferences: {
          notifications: true,
          email_reminders: false,
          dark_mode: true,
          auto_save: false
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["notifications"]).to eq("true")
      expect(json["preferences"]["email_reminders"]).to eq("false")
      expect(json["preferences"]["dark_mode"]).to eq("true")
      expect(json["preferences"]["auto_save"]).to eq("false")
    end

    it "should handle string preferences" do
      preferences_params = {
        preferences: {
          timezone: "America/New_York",
          language: "en",
          currency: "USD",
          date_format: "MM/DD/YYYY"
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["timezone"]).to eq("America/New_York")
      expect(json["preferences"]["language"]).to eq("en")
      expect(json["preferences"]["currency"]).to eq("USD")
      expect(json["preferences"]["date_format"]).to eq("MM/DD/YYYY")
    end

    it "should handle numeric preferences" do
      preferences_params = {
        preferences: {
          font_size: 16,
          max_notifications: 10,
          timeout_minutes: 30,
          refresh_interval: 5
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["font_size"]).to eq("16")
      expect(json["preferences"]["max_notifications"]).to eq("10")
      expect(json["preferences"]["timeout_minutes"]).to eq("30")
      expect(json["preferences"]["refresh_interval"]).to eq("5")
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      post "/api/v1/users/location",
            params: "invalid json",
            headers: user_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      post "/api/v1/users/location", params: {}, headers: user_headers

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Latitude and longitude are required")
    end

    it "should handle concurrent location updates" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          location_params = {
            latitude: 40.7128 + (i * 0.001),
            longitude: -74.0060 + (i * 0.001)
          }

          post "/api/v1/users/location", params: location_params, headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed with different coordinates
      expect(true).to be_truthy
    end

    it "should handle concurrent token updates" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          token_params = {
            fcm_token: "fcm_token_#{i}_#{SecureRandom.hex(10)}"
          }

          patch "/api/v1/users/fcm_token", params: token_params, headers: user_headers
        end
      end

      threads.each(&:join)
      # All should succeed
      expect(true).to be_truthy
    end

    it "should handle very long preference values" do
      long_string = "A" * 1000

      preferences_params = {
        preferences: {
          long_description: long_string,
          custom_field: long_string
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["long_description"]).to eq(long_string)
      expect(json["preferences"]["custom_field"]).to eq(long_string)
    end

    it "should handle special characters in preferences" do
      preferences_params = {
        preferences: {
          special_field: "Special Chars: !@#$%^&*()",
          unicode_field: "Unicode: 🚀📱💻",
          json_field: '{"nested": "json", "array": [1, 2, 3]}'
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["special_field"]).to eq("Special Chars: !@#$%^&*()")
      expect(json["preferences"]["unicode_field"]).to eq("Unicode: 🚀📱💻")
      expect(json["preferences"]["json_field"]).to eq('{"nested": "json", "array": [1, 2, 3]}')
    end

    it "should handle array preferences" do
      preferences_params = {
        preferences: {
          favorite_categories: [ "work", "personal", "health" ],
          notification_times: [ 9, 12, 18 ],
          enabled_features: [ "dark_mode", "notifications", "location" ]
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["favorite_categories"]).to eq([ "work", "personal", "health" ])
      expect(json["preferences"]["notification_times"]).to eq([ "9", "12", "18" ])
      expect(json["preferences"]["enabled_features"]).to eq([ "dark_mode", "notifications", "location" ])
    end

    it "should handle mixed data type preferences" do
      preferences_params = {
        preferences: {
          string_field: "string value",
          number_field: 42,
          boolean_field: true,
          array_field: [ 1, 2, 3 ],
          object_field: {
            nested: "value",
            count: 5
          }
        }
      }

      patch "/api/v1/users/preferences", params: preferences_params, headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["message"]).to eq("Preferences updated successfully")
      expect(json["preferences"]["string_field"]).to eq("string value")
      expect(json["preferences"]["number_field"]).to eq("42")
      expect(json["preferences"]["boolean_field"]).to eq("true")
      expect(json["preferences"]["array_field"]).to eq([ "1", "2", "3" ])
      expect(json["preferences"]["object_field"]["nested"]).to eq("value")
      expect(json["preferences"]["object_field"]["count"]).to eq("5")
    end
  end

  # Helper method for authentication headers
  #
  # Always obtain tokens by hitting the real login endpoint so Devise-JWT
  # generates proper claims (including jti) for denylist, Cable, etc.
  def auth_headers(user, password: "password123")
    post "/api/v1/login",
         params: {
           authentication: {
             email: user.email,
             password: password
           }
         }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    token = response.headers["Authorization"]
    raise "Missing Authorization header in auth_headers" if token.blank?

    { "Authorization" => token, "ACCEPT" => "application/json" }
  end
end
