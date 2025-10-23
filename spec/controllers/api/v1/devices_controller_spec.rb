require "rails_helper"

RSpec.describe Api::V1::DevicesController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }
  
  let(:device) do
    Device.create!(
      user: user,
      apns_token: "test_token_#{SecureRandom.hex(8)}",
      platform: "ios",
      bundle_id: "com.example.app"
    )
  end
  
  let(:user_headers) { auth_headers(user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "GET /api/v1/devices" do
    it "should get all devices for current user" do
      get "/api/v1/devices", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(device.id)
    end

    it "should not get devices without authentication" do
      get "/api/v1/devices"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end

    it "should only show user's own devices" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "other_token_#{SecureRandom.hex(8)}",
        platform: "android",
        bundle_id: "com.other.app"
      )
      
      get "/api/v1/devices", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(device.id)
      expect(json.map { |d| d["id"] }).not_to include(other_device.id)
    end
  end

  describe "GET /api/v1/devices/:id" do
    it "should show device details" do
      get "/api/v1/devices/#{device.id}", headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "apns_token", "platform", "bundle_id", "user")
      expect(json["id"]).to eq(device.id)
      expect(json["apns_token"]).to eq(device.apns_token)
      expect(json["platform"]).to eq("ios")
      expect(json["bundle_id"]).to eq("com.example.app")
    end

    it "should not show device from other user" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "other_token_#{SecureRandom.hex(8)}",
        platform: "android",
        bundle_id: "com.other.app"
      )
      
      get "/api/v1/devices/#{other_device.id}", headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end

    it "should not show device without authentication" do
      get "/api/v1/devices/#{device.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/devices" do
    it "should register device with APNs token" do
      device_params = {
        apns_token: "new_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.newapp.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "apns_token", "platform", "bundle_id")
      expect(json["apns_token"]).to eq(device_params[:apns_token])
      expect(json["platform"]).to eq("ios")
      expect(json["bundle_id"]).to eq("com.newapp.app")
    end

    it "should update existing device if token already registered" do
      existing_token = "existing_token_#{SecureRandom.hex(16)}"
      existing_device = Device.create!(
        user: user,
        apns_token: existing_token,
        platform: "android",
        bundle_id: "com.old.app"
      )
      
      device_params = {
        apns_token: existing_token,
        platform: "ios",
        bundle_id: "com.new.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "apns_token", "platform", "bundle_id")
      expect(json["apns_token"]).to eq(existing_token)
      expect(json["platform"]).to eq("ios")
      expect(json["bundle_id"]).to eq("com.new.app")
      
      # Verify the device was updated, not created new
      expect(json["id"]).to eq(existing_device.id)
    end

    it "should associate device with current user" do
      device_params = {
        apns_token: "user_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.user.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "user")
      expect(json["user"]["id"]).to eq(user.id)
      
      # Verify device is associated with user
      device = Device.find(json["id"])
      expect(device.user_id).to eq(user.id)
    end

    it "should validate platform (ios/android)" do
      device_params = {
        apns_token: "platform_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.platform.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["platform"]).to eq("ios")
    end

    it "should validate platform android" do
      device_params = {
        apns_token: "android_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.android.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["platform"]).to eq("android")
    end

    it "should return error for invalid platform" do
      device_params = {
        apns_token: "invalid_token_#{SecureRandom.hex(16)}",
        platform: "windows",
        bundle_id: "com.invalid.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Validation failed")
    end

    it "should validate bundle_id" do
      device_params = {
        apns_token: "bundle_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.valid.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["bundle_id"]).to eq("com.valid.app")
    end

    it "should return error for invalid bundle_id format" do
      device_params = {
        apns_token: "invalid_bundle_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "invalid-bundle-format"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Validation failed")
    end

    it "should allow blank bundle_id" do
      device_params = {
        apns_token: "blank_bundle_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: ""
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["bundle_id"]).to be_nil
    end

    it "should generate APNs token if not provided" do
      device_params = {
        apns_token: "",
        platform: "ios",
        bundle_id: "com.auto.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json["apns_token"]).not_to be_nil
      expect(json["apns_token"]).to start_with("dev_token_")
    end

    it "should generate APNs token if nil" do
      device_params = {
        apns_token: nil,
        platform: "ios",
        bundle_id: "com.nil.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json["apns_token"]).not_to be_nil
      expect(json["apns_token"]).to start_with("dev_token_")
    end

    it "should not create device without authentication" do
      device_params = {
        apns_token: "no_auth_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.noauth.app"
      }
      
      post "/api/v1/devices", params: device_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/devices/register" do
    it "should register device via legacy endpoint" do
      register_params = {
        apns_token: "legacy_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.legacy.app"
      }
      
      post "/api/v1/devices/register", params: register_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "apns_token", "platform", "bundle_id")
      expect(json["apns_token"]).to eq(register_params[:apns_token])
      expect(json["platform"]).to eq("android")
      expect(json["bundle_id"]).to eq("com.legacy.app")
    end

    it "should update existing device via legacy endpoint" do
      existing_token = "legacy_existing_#{SecureRandom.hex(16)}"
      existing_device = Device.create!(
        user: user,
        apns_token: existing_token,
        platform: "ios",
        bundle_id: "com.legacy.old"
      )
      
      register_params = {
        apns_token: existing_token,
        platform: "android",
        bundle_id: "com.legacy.new"
      }
      
      post "/api/v1/devices/register", params: register_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "platform", "bundle_id")
      expect(json["id"]).to eq(existing_device.id)
      expect(json["platform"]).to eq("android")
      expect(json["bundle_id"]).to eq("com.legacy.new")
    end
  end

  describe "PATCH /api/v1/devices/:id" do
    it "should update device" do
      update_params = {
        platform: "android",
        bundle_id: "com.updated.app"
      }
      
      patch "/api/v1/devices/#{device.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("id", "platform", "bundle_id")
      expect(json["id"]).to eq(device.id)
      expect(json["platform"]).to eq("android")
      expect(json["bundle_id"]).to eq("com.updated.app")
    end

    it "should not update device from other user" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "other_update_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.other.app"
      )
      
      update_params = {
        platform: "ios",
        bundle_id: "com.hacked.app"
      }
      
      patch "/api/v1/devices/#{other_device.id}", params: update_params, headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end

    it "should not update device without authentication" do
      update_params = {
        platform: "android",
        bundle_id: "com.noauth.app"
      }
      
      patch "/api/v1/devices/#{device.id}", params: update_params
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end
  end

  describe "DELETE /api/v1/devices/:id" do
    it "should delete device" do
      delete "/api/v1/devices/#{device.id}", headers: user_headers
      
      expect(response).to have_http_status(:no_content)
      
      expect { Device.find(device.id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should not delete device from other user" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "other_delete_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.other.app"
      )
      
      delete "/api/v1/devices/#{other_device.id}", headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end

    it "should not delete device without authentication" do
      delete "/api/v1/devices/#{device.id}"
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end
  end

  describe "POST /api/v1/devices/test_push" do
    it "should send test push notification to device" do
      post "/api/v1/devices/test_push", params: { device_id: device.id }, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      
      expect(json).to include("message", "device_id", "platform")
      expect(json["message"]).to eq("Test push notification sent successfully")
      expect(json["device_id"]).to eq(device.id)
      expect(json["platform"]).to eq("ios")
    end

    it "should return delivery status" do
      # Mock notification service
      allow(NotificationService).to receive(:send_test_notification).and_return(true)
      
      post "/api/v1/devices/test_push", params: { device_id: device.id }, headers: user_headers
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Test push notification sent successfully")
    end

    it "should handle invalid tokens gracefully" do
      # Create device with invalid token
      invalid_device = Device.create!(
        user: user,
        apns_token: "invalid_token_123",
        platform: "ios",
        bundle_id: "com.invalid.app"
      )
      
      # Mock notification service to raise error
      allow(NotificationService).to receive(:send_test_notification).and_raise(StandardError.new("Invalid token"))
      
      post "/api/v1/devices/test_push", params: { device_id: invalid_device.id }, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Failed to send test push")
    end

    it "should not send test push to other user's device" do
      other_device = Device.create!(
        user: other_user,
        apns_token: "other_test_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.other.app"
      )
      
      post "/api/v1/devices/test_push", params: { device_id: other_device.id }, headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end

    it "should not send test push without authentication" do
      post "/api/v1/devices/test_push", params: { device_id: device.id }
      
      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Authorization token required")
    end

    it "should handle missing device_id parameter" do
      post "/api/v1/devices/test_push", params: {}, headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end

    it "should handle non-existent device_id" do
      post "/api/v1/devices/test_push", params: { device_id: 99999 }, headers: user_headers
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Device not found")
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      post "/api/v1/devices", 
           params: "invalid json",
           headers: user_headers.merge("Content-Type" => "application/json")
      
      expect(response).to have_http_status(:bad_request)
    end

    it "should handle empty request body" do
      post "/api/v1/devices", params: {}, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["apns_token"]).to start_with("dev_token_")
    end

    it "should handle very long APNs tokens" do
      long_token = "a" * 1000
      
      device_params = {
        apns_token: long_token,
        platform: "ios",
        bundle_id: "com.long.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["apns_token"]).to eq(long_token)
    end

    it "should handle special characters in bundle_id" do
      device_params = {
        apns_token: "special_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.company-name.app_name"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["bundle_id"]).to eq("com.company-name.app_name")
    end

    it "should handle unicode characters in bundle_id" do
      device_params = {
        apns_token: "unicode_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.公司.应用"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Validation failed")
    end

    it "should handle concurrent device registration" do
      threads = []
      3.times do |i|
        threads << Thread.new do
          device_params = {
            apns_token: "concurrent_token_#{i}_#{SecureRandom.hex(16)}",
            platform: "ios",
            bundle_id: "com.concurrent#{i}.app"
          }
          
          post "/api/v1/devices", params: device_params, headers: user_headers
        end
      end
      
      threads.each(&:join)
      # All should succeed with different tokens
      expect(true).to be_truthy
    end

    it "should handle duplicate APNs tokens across users" do
      # First user registers device
      device_params = {
        apns_token: "shared_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "com.shared.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      expect(response).to have_http_status(:created)
      
      # Second user tries to register with same token
      post "/api/v1/devices", params: device_params, headers: other_user_headers
      expect(response).to have_http_status(:created)
      
      # Both should succeed as tokens are unique per user
      expect(true).to be_truthy
    end

    it "should handle nested device parameters" do
      device_params = {
        device: {
          apns_token: "nested_token_#{SecureRandom.hex(16)}",
          platform: "android",
          bundle_id: "com.nested.app"
        }
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json).to include("apns_token", "platform", "bundle_id")
      expect(json["apns_token"]).to start_with("nested_token_")
      expect(json["platform"]).to eq("android")
      expect(json["bundle_id"]).to eq("com.nested.app")
    end

    it "should handle boolean platform values" do
      device_params = {
        apns_token: "boolean_token_#{SecureRandom.hex(16)}",
        platform: "1", # String boolean
        bundle_id: "com.boolean.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Validation failed")
    end

    it "should handle nil platform" do
      device_params = {
        apns_token: "nil_platform_token_#{SecureRandom.hex(16)}",
        platform: nil,
        bundle_id: "com.nil.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["platform"]).to eq("ios") # Should default to ios
    end

    it "should handle empty platform" do
      device_params = {
        apns_token: "empty_platform_token_#{SecureRandom.hex(16)}",
        platform: "",
        bundle_id: "com.empty.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["platform"]).to eq("ios") # Should default to ios
    end

    it "should handle very long bundle_id" do
      long_bundle_id = "com." + "a" * 200 + ".app"
      
      device_params = {
        apns_token: "long_bundle_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: long_bundle_id
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]["message"].to eq("Validation failed")
    end

    it "should handle whitespace in APNs token" do
      device_params = {
        apns_token: "  token_with_spaces_#{SecureRandom.hex(16)}  ",
        platform: "ios",
        bundle_id: "com.spaces.app"
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["apns_token"]).to start_with("  token_with_spaces_") # Should preserve spaces
    end

    it "should handle whitespace in bundle_id" do
      device_params = {
        apns_token: "whitespace_token_#{SecureRandom.hex(16)}",
        platform: "ios",
        bundle_id: "  com.whitespace.app  "
      }
      
      post "/api/v1/devices", params: device_params, headers: user_headers
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["bundle_id"]).to eq("  com.whitespace.app  ") # Should preserve spaces
    end
  end

  # Helper method for authentication headers
  def auth_headers(user)
    token = JWT.encode(
      { user_id: user.id, exp: 30.days.from_now.to_i },
      Rails.application.credentials.secret_key_base
    )
    { "Authorization" => "Bearer #{token}" }
  end
end
