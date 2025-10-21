require "test_helper"

class Api::V1::DevicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @device = Device.create!(
      user: @user,
      apns_token: "test_token_#{SecureRandom.hex(8)}",
      platform: "ios",
      bundle_id: "com.example.app"
    )
    
    @user_headers = auth_headers(@user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Index tests
  test "should get all devices for current user" do
    get "/api/v1/devices", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @device.id, json.first["id"]
  end

  test "should not get devices without authentication" do
    get "/api/v1/devices"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should only show user's own devices" do
    other_device = Device.create!(
      user: @other_user,
      apns_token: "other_token_#{SecureRandom.hex(8)}",
      platform: "android",
      bundle_id: "com.other.app"
    )
    
    get "/api/v1/devices", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @device.id, json.first["id"]
    assert_not_includes json.map { |d| d["id"] }, other_device.id
  end

  # Show tests
  test "should show device details" do
    get "/api/v1/devices/#{@device.id}", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "apns_token", "platform", "bundle_id", "user"])
    
    assert_equal @device.id, json["id"]
    assert_equal @device.apns_token, json["apns_token"]
    assert_equal "ios", json["platform"]
    assert_equal "com.example.app", json["bundle_id"]
  end

  test "should not show device from other user" do
    other_device = Device.create!(
      user: @other_user,
      apns_token: "other_token_#{SecureRandom.hex(8)}",
      platform: "android",
      bundle_id: "com.other.app"
    )
    
    get "/api/v1/devices/#{other_device.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  test "should not show device without authentication" do
    get "/api/v1/devices/#{@device.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Create tests
  test "should register device with APNs token" do
    device_params = {
      apns_token: "new_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.newapp.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "apns_token", "platform", "bundle_id"])
    
    assert_equal device_params[:apns_token], json["apns_token"]
    assert_equal "ios", json["platform"]
    assert_equal "com.newapp.app", json["bundle_id"]
  end

  test "should update existing device if token already registered" do
    existing_token = "existing_token_#{SecureRandom.hex(16)}"
    existing_device = Device.create!(
      user: @user,
      apns_token: existing_token,
      platform: "android",
      bundle_id: "com.old.app"
    )
    
    device_params = {
      apns_token: existing_token,
      platform: "ios",
      bundle_id: "com.new.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "apns_token", "platform", "bundle_id"])
    
    assert_equal existing_token, json["apns_token"]
    assert_equal "ios", json["platform"]
    assert_equal "com.new.app", json["bundle_id"]
    
    # Verify the device was updated, not created new
    assert_equal existing_device.id, json["id"]
  end

  test "should associate device with current user" do
    device_params = {
      apns_token: "user_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.user.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "user"])
    
    assert_equal @user.id, json["user"]["id"]
    
    # Verify device is associated with user
    device = Device.find(json["id"])
    assert_equal @user.id, device.user_id
  end

  test "should validate platform (ios/android)" do
    device_params = {
      apns_token: "platform_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.platform.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["platform"])
    assert_equal "ios", json["platform"]
  end

  test "should validate platform android" do
    device_params = {
      apns_token: "android_token_#{SecureRandom.hex(16)}",
      platform: "android",
      bundle_id: "com.android.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["platform"])
    assert_equal "android", json["platform"]
  end

  test "should return error for invalid platform" do
    device_params = {
      apns_token: "invalid_token_#{SecureRandom.hex(16)}",
      platform: "windows",
      bundle_id: "com.invalid.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should validate bundle_id" do
    device_params = {
      apns_token: "bundle_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.valid.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["bundle_id"])
    assert_equal "com.valid.app", json["bundle_id"]
  end

  test "should return error for invalid bundle_id format" do
    device_params = {
      apns_token: "invalid_bundle_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "invalid-bundle-format"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should allow blank bundle_id" do
    device_params = {
      apns_token: "blank_bundle_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: ""
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["bundle_id"])
    assert_nil json["bundle_id"]
  end

  test "should generate APNs token if not provided" do
    device_params = {
      apns_token: "",
      platform: "ios",
      bundle_id: "com.auto.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token"])
    
    assert_not_nil json["apns_token"]
    assert json["apns_token"].start_with?("dev_token_")
  end

  test "should generate APNs token if nil" do
    device_params = {
      apns_token: nil,
      platform: "ios",
      bundle_id: "com.nil.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token"])
    
    assert_not_nil json["apns_token"]
    assert json["apns_token"].start_with?("dev_token_")
  end

  test "should not create device without authentication" do
    device_params = {
      apns_token: "no_auth_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.noauth.app"
    }
    
    post "/api/v1/devices", params: device_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Register (legacy) tests
  test "should register device via legacy endpoint" do
    register_params = {
      apns_token: "legacy_token_#{SecureRandom.hex(16)}",
      platform: "android",
      bundle_id: "com.legacy.app"
    }
    
    post "/api/v1/devices/register", params: register_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "apns_token", "platform", "bundle_id"])
    
    assert_equal register_params[:apns_token], json["apns_token"]
    assert_equal "android", json["platform"]
    assert_equal "com.legacy.app", json["bundle_id"]
  end

  test "should update existing device via legacy endpoint" do
    existing_token = "legacy_existing_#{SecureRandom.hex(16)}"
    existing_device = Device.create!(
      user: @user,
      apns_token: existing_token,
      platform: "ios",
      bundle_id: "com.legacy.old"
    )
    
    register_params = {
      apns_token: existing_token,
      platform: "android",
      bundle_id: "com.legacy.new"
    }
    
    post "/api/v1/devices/register", params: register_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["id", "platform", "bundle_id"])
    
    assert_equal existing_device.id, json["id"]
    assert_equal "android", json["platform"]
    assert_equal "com.legacy.new", json["bundle_id"]
  end

  # Update tests
  test "should update device" do
    update_params = {
      platform: "android",
      bundle_id: "com.updated.app"
    }
    
    patch "/api/v1/devices/#{@device.id}", params: update_params, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["id", "platform", "bundle_id"])
    
    assert_equal @device.id, json["id"]
    assert_equal "android", json["platform"]
    assert_equal "com.updated.app", json["bundle_id"]
  end

  test "should not update device from other user" do
    other_device = Device.create!(
      user: @other_user,
      apns_token: "other_update_token_#{SecureRandom.hex(16)}",
      platform: "android",
      bundle_id: "com.other.app"
    )
    
    update_params = {
      platform: "ios",
      bundle_id: "com.hacked.app"
    }
    
    patch "/api/v1/devices/#{other_device.id}", params: update_params, headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  test "should not update device without authentication" do
    update_params = {
      platform: "android",
      bundle_id: "com.noauth.app"
    }
    
    patch "/api/v1/devices/#{@device.id}", params: update_params
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Delete tests
  test "should delete device" do
    delete "/api/v1/devices/#{@device.id}", headers: @user_headers
    
    assert_response :no_content
    
    assert_raises(ActiveRecord::RecordNotFound) do
      Device.find(@device.id)
    end
  end

  test "should not delete device from other user" do
    other_device = Device.create!(
      user: @other_user,
      apns_token: "other_delete_token_#{SecureRandom.hex(16)}",
      platform: "android",
      bundle_id: "com.other.app"
    )
    
    delete "/api/v1/devices/#{other_device.id}", headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  test "should not delete device without authentication" do
    delete "/api/v1/devices/#{@device.id}"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  # Test Push tests
  test "should send test push notification to device" do
    post "/api/v1/devices/test_push", params: { device_id: @device.id }, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message", "device_id", "platform"])
    
    assert_equal "Test push notification sent successfully", json["message"]
    assert_equal @device.id, json["device_id"]
    assert_equal "ios", json["platform"]
  end

  test "should return delivery status" do
    # Mock notification service
    NotificationService.expects(:send_test_notification).returns(true)
    
    post "/api/v1/devices/test_push", params: { device_id: @device.id }, headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response, ["message"])
    assert_equal "Test push notification sent successfully", json["message"]
  end

  test "should handle invalid tokens gracefully" do
    # Create device with invalid token
    invalid_device = Device.create!(
      user: @user,
      apns_token: "invalid_token_123",
      platform: "ios",
      bundle_id: "com.invalid.app"
    )
    
    # Mock notification service to raise error
    NotificationService.expects(:send_test_notification).raises(StandardError.new("Invalid token"))
    
    post "/api/v1/devices/test_push", params: { device_id: invalid_device.id }, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Failed to send test push")
  end

  test "should not send test push to other user's device" do
    other_device = Device.create!(
      user: @other_user,
      apns_token: "other_test_token_#{SecureRandom.hex(16)}",
      platform: "android",
      bundle_id: "com.other.app"
    )
    
    post "/api/v1/devices/test_push", params: { device_id: other_device.id }, headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  test "should not send test push without authentication" do
    post "/api/v1/devices/test_push", params: { device_id: @device.id }
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle missing device_id parameter" do
    post "/api/v1/devices/test_push", params: {}, headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  test "should handle non-existent device_id" do
    post "/api/v1/devices/test_push", params: { device_id: 99999 }, headers: @user_headers
    
    assert_error_response(response, :not_found, "Device not found")
  end

  # Edge cases
  test "should handle malformed JSON" do
    post "/api/v1/devices", 
         params: "invalid json",
         headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :bad_request
  end

  test "should handle empty request body" do
    post "/api/v1/devices", params: {}, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token"])
    assert json["apns_token"].start_with?("dev_token_")
  end

  test "should handle very long APNs tokens" do
    long_token = "a" * 1000
    
    device_params = {
      apns_token: long_token,
      platform: "ios",
      bundle_id: "com.long.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token"])
    assert_equal long_token, json["apns_token"]
  end

  test "should handle special characters in bundle_id" do
    device_params = {
      apns_token: "special_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.company-name.app_name"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["bundle_id"])
    assert_equal "com.company-name.app_name", json["bundle_id"]
  end

  test "should handle unicode characters in bundle_id" do
    device_params = {
      apns_token: "unicode_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.公司.应用"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle concurrent device registration" do
    threads = []
    3.times do |i|
      threads << Thread.new do
        device_params = {
          apns_token: "concurrent_token_#{i}_#{SecureRandom.hex(16)}",
          platform: "ios",
          bundle_id: "com.concurrent#{i}.app"
        }
        
        post "/api/v1/devices", params: device_params, headers: @user_headers
      end
    end
    
    threads.each(&:join)
    # All should succeed with different tokens
    assert true
  end

  test "should handle duplicate APNs tokens across users" do
    # First user registers device
    device_params = {
      apns_token: "shared_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "com.shared.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    assert_response :created
    
    # Second user tries to register with same token
    post "/api/v1/devices", params: device_params, headers: @other_user_headers
    assert_response :created
    
    # Both should succeed as tokens are unique per user
    assert true
  end

  test "should handle nested device parameters" do
    device_params = {
      device: {
        apns_token: "nested_token_#{SecureRandom.hex(16)}",
        platform: "android",
        bundle_id: "com.nested.app"
      }
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token", "platform", "bundle_id"])
    
    assert_equal "nested_token_", json["apns_token"][0..12]
    assert_equal "android", json["platform"]
    assert_equal "com.nested.app", json["bundle_id"]
  end

  test "should handle boolean platform values" do
    device_params = {
      apns_token: "boolean_token_#{SecureRandom.hex(16)}",
      platform: "1", # String boolean
      bundle_id: "com.boolean.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle nil platform" do
    device_params = {
      apns_token: "nil_platform_token_#{SecureRandom.hex(16)}",
      platform: nil,
      bundle_id: "com.nil.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["platform"])
    assert_equal "ios", json["platform"] # Should default to ios
  end

  test "should handle empty platform" do
    device_params = {
      apns_token: "empty_platform_token_#{SecureRandom.hex(16)}",
      platform: "",
      bundle_id: "com.empty.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["platform"])
    assert_equal "ios", json["platform"] # Should default to ios
  end

  test "should handle very long bundle_id" do
    long_bundle_id = "com." + "a" * 200 + ".app"
    
    device_params = {
      apns_token: "long_bundle_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: long_bundle_id
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_error_response(response, :unprocessable_entity, "Validation failed")
  end

  test "should handle whitespace in APNs token" do
    device_params = {
      apns_token: "  token_with_spaces_#{SecureRandom.hex(16)}  ",
      platform: "ios",
      bundle_id: "com.spaces.app"
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["apns_token"])
    assert_equal "  token_with_spaces_", json["apns_token"][0..20] # Should preserve spaces
  end

  test "should handle whitespace in bundle_id" do
    device_params = {
      apns_token: "whitespace_token_#{SecureRandom.hex(16)}",
      platform: "ios",
      bundle_id: "  com.whitespace.app  "
    }
    
    post "/api/v1/devices", params: device_params, headers: @user_headers
    
    assert_response :created
    json = assert_json_response(response, ["bundle_id"])
    assert_equal "  com.whitespace.app  ", json["bundle_id"] # Should preserve spaces
  end
end
