require "test_helper"

class DeviceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @device = Device.new(
      user: @user,
      apns_token: "test_token_123",
      platform: "ios",
      bundle_id: "com.focusmate.app"
    )
  end

  test "should belong to user" do
    assert @device.valid?
    assert_equal @user, @device.user
  end

  test "should require apns_token" do
    @device.apns_token = nil
    assert_not @device.valid?
    assert_includes @device.errors[:apns_token], "can't be blank"
  end

  test "should validate unique apns_token" do
    @device.save!
    
    duplicate_device = Device.new(
      user: @user,
      apns_token: @device.apns_token,
      platform: "android"
    )
    
    assert_not duplicate_device.valid?
    assert_includes duplicate_device.errors[:apns_token], "has already been taken"
  end

  test "should default platform to 'ios'" do
    device = Device.create!(
      user: @user,
      apns_token: "new_token_123"
    )
    assert_equal "ios", device.platform
  end

  test "should validate platform (ios/android)" do
    # Test valid platforms
    @device.platform = "ios"
    assert @device.valid?

    @device.platform = "android"
    assert @device.valid?

    # Test invalid platforms
    @device.platform = "windows"
    assert_not @device.valid?
    assert_includes @device.errors[:platform], "is not included in the list"

    @device.platform = "web"
    assert_not @device.valid?
    assert_includes @device.errors[:platform], "is not included in the list"

    @device.platform = ""
    assert_not @device.valid?
    assert_includes @device.errors[:platform], "is not included in the list"
  end

  test "should validate bundle_id format" do
    # Test valid bundle_id formats
    valid_bundle_ids = [
      "com.focusmate.app",
      "com.company.app",
      "com.example.app.debug",
      "com.test.app.staging",
      "com.app.name",
      "com.123.456"
    ]

    valid_bundle_ids.each do |bundle_id|
      @device.bundle_id = bundle_id
      assert @device.valid?, "Bundle ID '#{bundle_id}' should be valid"
    end

    # Test invalid bundle_id formats
    invalid_bundle_ids = [
      "invalid-format",
      "com",
      "com.",
      ".com.app",
      "com..app",
      "com.app.",
      "com app",
      "com/app",
      "com@app",
      "com#app",
      "com$app",
      "com%app",
      "com^app",
      "com&app",
      "com*app",
      "com+app",
      "com=app",
      "com[app",
      "com]app",
      "com{app",
      "com}app",
      "com|app",
      "com\\app",
      "com;app",
      "com:app",
      "com'app",
      "com\"app",
      "com<app",
      "com>app",
      "com,app",
      "com?app",
      "com/app",
      "com~app",
      "com`app"
    ]

    invalid_bundle_ids.each do |bundle_id|
      @device.bundle_id = bundle_id
      assert_not @device.valid?, "Bundle ID '#{bundle_id}' should be invalid"
    end
  end

  test "should allow multiple devices per user" do
    @device.save!
    
    second_device = Device.create!(
      user: @user,
      apns_token: "second_token_456",
      platform: "android",
      bundle_id: "com.focusmate.app"
    )
    
    assert second_device.valid?
    assert second_device.persisted?
    assert_equal 2, @user.devices.count
  end

  test "should allow same user to have devices on different platforms" do
    ios_device = Device.create!(
      user: @user,
      apns_token: "ios_token_123",
      platform: "ios",
      bundle_id: "com.focusmate.app"
    )
    
    android_device = Device.create!(
      user: @user,
      apns_token: "android_token_456",
      platform: "android",
      bundle_id: "com.focusmate.app"
    )
    
    assert ios_device.valid?
    assert android_device.valid?
    assert_equal 2, @user.devices.count
  end

  test "should update token if device re-registers" do
    @device.save!
    original_token = @device.apns_token
    
    # Simulate device re-registration with new token
    new_token = "updated_token_789"
    @device.update!(apns_token: new_token)
    
    assert_equal new_token, @device.apns_token
    assert_not_equal original_token, @device.apns_token
  end

  test "should remove device if token expires" do
    @device.save!
    device_id = @device.id
    
    # Simulate token expiration by deleting the device
    @device.destroy!
    
    assert_raises(ActiveRecord::RecordNotFound) do
      Device.find(device_id)
    end
  end

  test "should check if device is iOS" do
    @device.platform = "ios"
    assert @device.ios?
    assert_not @device.android?
  end

  test "should check if device is Android" do
    @device.platform = "android"
    assert @device.android?
    assert_not @device.ios?
  end

  test "should get device summary for display" do
    @device.save!
    summary = @device.summary
    
    assert_equal @device.id, summary[:id]
    assert_equal "ios", summary[:platform]
    assert_equal "com.focusmate.app", summary[:bundle_id]
    assert_equal @device.created_at, summary[:created_at]
  end

  test "should get formatted device name" do
    @device.platform = "ios"
    assert_equal "Ios Device", @device.display_name
    
    @device.platform = "android"
    assert_equal "Android Device", @device.display_name
  end

  test "should use ios scope" do
    ios_device = Device.create!(
      user: @user,
      apns_token: "ios_token_123",
      platform: "ios"
    )
    
    android_device = Device.create!(
      user: @user,
      apns_token: "android_token_456",
      platform: "android"
    )
    
    ios_devices = Device.ios
    assert_includes ios_devices, ios_device
    assert_not_includes ios_devices, android_device
  end

  test "should use android scope" do
    ios_device = Device.create!(
      user: @user,
      apns_token: "ios_token_123",
      platform: "ios"
    )
    
    android_device = Device.create!(
      user: @user,
      apns_token: "android_token_456",
      platform: "android"
    )
    
    android_devices = Device.android
    assert_includes android_devices, android_device
    assert_not_includes android_devices, ios_device
  end

  test "should use for_user scope" do
    other_user = create_test_user
    user_device = Device.create!(
      user: @user,
      apns_token: "user_token_123",
      platform: "ios"
    )
    
    other_device = Device.create!(
      user: other_user,
      apns_token: "other_token_456",
      platform: "android"
    )
    
    user_devices = Device.for_user(@user)
    assert_includes user_devices, user_device
    assert_not_includes user_devices, other_device
  end

  test "should handle nil bundle_id" do
    @device.bundle_id = nil
    assert @device.valid?
    assert @device.save
  end

  test "should handle empty bundle_id" do
    @device.bundle_id = ""
    assert @device.valid?
    assert @device.save
  end

  test "should validate apns_token uniqueness across all users" do
    other_user = create_test_user
    @device.save!
    
    # Same token for different user should be invalid
    other_device = Device.new(
      user: other_user,
      apns_token: @device.apns_token,
      platform: "android"
    )
    
    assert_not other_device.valid?
    assert_includes other_device.errors[:apns_token], "has already been taken"
  end

  test "should handle long apns_token" do
    long_token = "a" * 1000
    @device.apns_token = long_token
    assert @device.valid?
    assert @device.save
  end

  test "should handle special characters in apns_token" do
    special_token = "token_with_special_chars_!@#$%^&*()_+-=[]{}|;':\",./<>?"
    @device.apns_token = special_token
    assert @device.valid?
    assert @device.save
  end

  test "should handle numeric apns_token" do
    numeric_token = "1234567890"
    @device.apns_token = numeric_token
    assert @device.valid?
    assert @device.save
  end

  test "should handle mixed case apns_token" do
    mixed_token = "TokenWithMixedCase123"
    @device.apns_token = mixed_token
    assert @device.valid?
    assert @device.save
  end

  test "should create device with all attributes" do
    device = Device.create!(
      user: @user,
      apns_token: "complete_token_123",
      platform: "android",
      bundle_id: "com.focusmate.app"
    )
    
    assert device.persisted?
    assert_equal @user, device.user
    assert_equal "complete_token_123", device.apns_token
    assert_equal "android", device.platform
    assert_equal "com.focusmate.app", device.bundle_id
  end

  test "should handle device with minimal attributes" do
    device = Device.create!(
      user: @user,
      apns_token: "minimal_token_123"
    )
    
    assert device.persisted?
    assert_equal "ios", device.platform
    assert_nil device.bundle_id
  end

  test "should update device attributes" do
    @device.save!
    
    @device.update!(
      platform: "android",
      bundle_id: "com.focusmate.app.updated"
    )
    
    assert_equal "android", @device.platform
    assert_equal "com.focusmate.app.updated", @device.bundle_id
  end

  test "should handle device re-registration with same token" do
    @device.save!
    original_created_at = @device.created_at
    
    # Simulate device re-registration (same token, different attributes)
    @device.update!(
      platform: "android",
      bundle_id: "com.focusmate.app.updated"
    )
    
    # Created at should remain the same
    assert_equal original_created_at, @device.created_at
    # But updated_at should change
    assert @device.updated_at > original_created_at
  end

  test "should handle multiple devices with different bundle_ids" do
    device1 = Device.create!(
      user: @user,
      apns_token: "token_1",
      platform: "ios",
      bundle_id: "com.focusmate.app"
    )
    
    device2 = Device.create!(
      user: @user,
      apns_token: "token_2",
      platform: "ios",
      bundle_id: "com.focusmate.app.debug"
    )
    
    assert device1.valid?
    assert device2.valid?
    assert_equal 2, @user.devices.count
  end

  test "should handle device summary with nil bundle_id" do
    @device.bundle_id = nil
    @device.save!
    
    summary = @device.summary
    assert_nil summary[:bundle_id]
    assert_equal @device.id, summary[:id]
    assert_equal "ios", summary[:platform]
  end

  test "should handle display name for different platforms" do
    ios_device = Device.new(platform: "ios")
    android_device = Device.new(platform: "android")
    
    assert_equal "Ios Device", ios_device.display_name
    assert_equal "Android Device", android_device.display_name
  end

  test "should handle device with very long bundle_id" do
    long_bundle_id = "com." + "a" * 200 + ".app"
    @device.bundle_id = long_bundle_id
    
    # Should be valid if within database limits
    assert @device.valid?
  end

  test "should handle device with bundle_id containing numbers" do
    @device.bundle_id = "com.focusmate2024.app"
    assert @device.valid?
  end

  test "should handle device with bundle_id containing hyphens" do
    @device.bundle_id = "com.focus-mate.app"
    assert @device.valid?
  end

  test "should handle device with bundle_id containing underscores" do
    @device.bundle_id = "com.focus_mate.app"
    assert @device.valid?
  end

  test "should handle device with bundle_id containing multiple dots" do
    @device.bundle_id = "com.focusmate.app.staging.v2"
    assert @device.valid?
  end

  test "should handle device with bundle_id starting with number" do
    @device.bundle_id = "com.123app.app"
    assert @device.valid?
  end

  test "should handle device with bundle_id ending with number" do
    @device.bundle_id = "com.app.123"
    assert @device.valid?
  end

  test "should handle device with bundle_id containing mixed case" do
    @device.bundle_id = "com.FocusMate.App"
    assert @device.valid?
  end
end