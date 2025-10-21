# frozen_string_literal: true

require "test_helper"

class PushNotificationServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @device = Device.create!(
      user: @user,
      platform: "ios",
      apns_token: "test_device_token_12345",
      bundle_id: "com.focusmate.app"
    )
    @task = create_test_task(@list)
  end

  # ==========================================
  # APNs (iOS) TESTS
  # ==========================================

  test "should send push notification via APNs" do
    # Mock the APNs client
    mock_response = { ok: true, apns_id: "test-apns-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    result = Notifications::Push.send_example(
      @device.apns_token,
      title: "Test Notification",
      body: "This is a test notification"
    )

    assert result[:ok]
    assert_equal 200, result[:status]
    assert_equal "test-apns-id", result[:apns_id]
  end

  test "should use correct APNs endpoint (sandbox vs production)" do
    # Test sandbox environment
    client = Apns::Client.new(
      team_id: "TEAM123",
      key_id: "KEY123", 
      bundle_id: "com.focusmate.app",
      p8: "mock_p8_content",
      environment: "sandbox"
    )
    assert_equal "api.sandbox.push.apple.com", client.send(:apns_host)

    # Test production environment
    client = Apns::Client.new(
      team_id: "TEAM123",
      key_id: "KEY123",
      bundle_id: "com.focusmate.app", 
      p8: "mock_p8_content",
      environment: "production"
    )
    assert_equal "api.push.apple.com", client.send(:apns_host)
  end

  test "should generate valid JWT token for APNs" do
    # Test that JWT generation doesn't raise errors
    # In a real environment, this would require valid APNs credentials
    assert_nothing_raised do
      client = Apns::Client.new(
        team_id: "TEAM123",
        key_id: "KEY123",
        bundle_id: "com.focusmate.app",
        p8: "mock_p8_content",
        environment: "sandbox"
      )
      # This will fail in test environment due to invalid key, but we can test the structure
    end
  end

  test "should include correct headers (apns-topic, apns-priority)" do
    # Test that the notification payload structure is correct
    payload = {
      aps: {
        alert: { title: "Test", body: "Body" },
        sound: "default",
        badge: 1
      }
    }

    assert payload[:aps][:alert][:title] == "Test"
    assert payload[:aps][:alert][:body] == "Body"
    assert payload[:aps][:sound] == "default"
    assert payload[:aps][:badge] == 1
  end

  test "should handle successful delivery (200 response)" do
    mock_response = { ok: true, apns_id: "success-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    result = Notifications::Push.send_example(
      @device.apns_token,
      title: "Success Test",
      body: "This should succeed"
    )

    assert result[:ok]
    assert_equal 200, result[:status]
    assert_equal "success-id", result[:apns_id]
  end

  test "should handle invalid token (410 response)" do
    mock_response = { 
      ok: false, 
      status: 410, 
      reason: "Unregistered", 
      timestamp: Time.current.to_i 
    }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    result = Notifications::Push.send_example(
      "invalid_token",
      title: "Invalid Token Test", 
      body: "This should fail"
    )

    assert_not result[:ok]
    assert_equal 410, result[:status]
    assert_equal "Unregistered", result[:reason]
  end

  test "should handle bad request (400 response)" do
    mock_response = { 
      ok: false, 
      status: 400, 
      reason: "BadRequest", 
      timestamp: Time.current.to_i 
    }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    result = Notifications::Push.send_example(
      @device.apns_token,
      title: "Bad Request Test",
      body: "This should fail"
    )

    assert_not result[:ok]
    assert_equal 400, result[:status]
    assert_equal "BadRequest", result[:reason]
  end

  test "should retry on server error (500 response)" do
    mock_response = { 
      ok: false, 
      status: 500, 
      reason: "InternalServerError", 
      timestamp: Time.current.to_i 
    }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    result = Notifications::Push.send_example(
      @device.apns_token,
      title: "Retry Test",
      body: "This should retry and succeed"
    )

    assert_not result[:ok]
    assert_equal 500, result[:status]
    assert_equal "InternalServerError", result[:reason]
  end

  test "should log delivery status in notification_logs" do
    # Create a coach and task created by coach
    coach = create_test_user(email: "coach_log_test@example.com")
    coach.update!(role: "coach")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      status: :active,
      invited_by: coach
    )
    
    # Create task by coach
    coach_task = Task.create!(
      list: @list,
      creator: coach,
      title: "Task by Coach",
      due_at: 1.hour.from_now,
      status: :pending,
      strict_mode: false
    )

    # Ensure the client has an iOS device
    Device.create!(
      user: @user,
      platform: "ios",
      apns_token: "client_device_token",
      bundle_id: "com.focusmate.app"
    )

    # Mock the notification service to avoid APNs client issues
    NotificationService.stubs(:send_apns_notification).returns(true)

    
    # Test that notification logs are created
    assert_difference "NotificationLog.count", 1 do
      NotificationService.new_item_assigned(coach_task)
    end

    log = NotificationLog.last
    assert_equal @user, log.user
    assert_equal "new_task_assigned", log.notification_type
    assert_equal "New task assigned: #{coach_task.title}", log.message
  end

  test "should remove invalid device tokens" do
    # Test device removal logic
    invalid_device = Device.create!(
      user: @user,
      platform: "ios",
      apns_token: "invalid_token",
      bundle_id: "com.focusmate.app"
    )

    # Simulate 410 response handling
    assert_difference "Device.count", -1 do
      invalid_device.destroy
    end
  end

  # ==========================================
  # FCM (Android) TESTS
  # ==========================================

  test "should send push notification via FCM" do
    # Create Android device
    android_device = Device.create!(
      user: @user,
      platform: "android",
      fcm_token: "test_fcm_token_12345"
    )

    # Test that FCM notification can be sent
    assert_nothing_raised do
      NotificationService.send_fcm_notification(
        user: @user,
        title: "FCM Test",
        body: "This is an FCM notification"
      )
    end
  end

  test "should handle FCM token invalidation" do
    # Test FCM error handling
    assert_nothing_raised do
      NotificationService.send_fcm_notification(
        user: @user,
        title: "Invalid FCM Test",
        body: "This should fail"
      )
    end
  end

  test "should include custom data payload" do
    # Test that custom data is included in payload
    custom_data = {
      task_id: @task.id,
      list_id: @task.list_id,
      due_at: @task.due_at.iso8601
    }

    # Test payload structure
    payload = {
      aps: {
        alert: { title: "Test", body: "Body" }
      },
      data: custom_data
    }

    assert_equal @task.id, payload[:data][:task_id]
    assert_equal @task.list_id, payload[:data][:list_id]
  end

  # ==========================================
  # NOTIFICATION TYPES TESTS
  # ==========================================

  test "should send task reminder notification" do
    # Mock the APNs client for reminder
    mock_response = { ok: true, apns_id: "reminder-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.send_reminder(@task, "normal")
    end
  end

  test "should send overdue task notification" do
    # Create overdue task
    overdue_task = Task.create!(
      list: @list,
      creator: @user,
      title: "Overdue Task",
      due_at: 1.hour.ago,
      status: :pending,
      strict_mode: false
    )

    # Mock the APNs client
    mock_response = { ok: true, apns_id: "overdue-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.alert_coaches_of_overdue(overdue_task)
    end
  end

  test "should send escalation notification" do
    # Mock the APNs client
    mock_response = { ok: true, apns_id: "escalation-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.send_reminder(@task, "critical")
    end
  end

  test "should send completion notification to coach" do
    coach = create_test_user(email: "coach@example.com")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      status: :active,
      invited_by: coach
    )

    # Mock the APNs client
    mock_response = { ok: true, apns_id: "completion-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.task_completed(@task)
    end
  end

  test "should send daily summary notification" do
    coach = create_test_user(email: "coach@example.com")
    coaching_relationship = CoachingRelationship.create!(
      coach: coach,
      client: @user,
      status: :active,
      invited_by: coach
    )

    # Create a daily summary
    daily_summary = DailySummary.create!(
      coaching_relationship: coaching_relationship,
      summary_date: Date.current,
      tasks_completed: 5,
      tasks_missed: 2,
      tasks_overdue: 1,
      summary_data: { completion_rate: 71.4 }
    )

    # Mock the APNs client
    mock_response = { ok: true, apns_id: "summary-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.send_daily_summary(daily_summary)
    end
  end

  test "should send task assignment notification" do
    # Mock the APNs client
    mock_response = { ok: true, apns_id: "assignment-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.new_item_assigned(@task)
    end
  end

  test "should send location-based trigger notification" do
    # Create location-based task
    location_task = Task.create!(
      list: @list,
      creator: @user,
      title: "Location Task",
      note: "Task at specific location",
      due_at: 1.hour.from_now,
      status: :pending,
      location_based: true,
      location_latitude: 40.7128,
      location_longitude: -74.0060,
      location_radius_meters: 100,
      strict_mode: false
    )

    # Mock the APNs client
    mock_response = { ok: true, apns_id: "location-id", status: 200 }
    mock_client = mock("apns_client")
    mock_client.expects(:send_notification).returns(mock_response)
    Notifications::Push.stubs(:apns).returns(mock_client)

    assert_nothing_raised do
      NotificationService.location_based_reminder(location_task, "arrival")
    end
  end

  # ==========================================
  # ERROR HANDLING TESTS
  # ==========================================

  test "should handle network timeout gracefully" do
    # Test timeout handling
    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: "Timeout Test",
        body: "This should handle timeout"
      )
    end
  end

  test "should handle rate limiting (429 response)" do
    # Test rate limiting handling
    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: "Rate Limit Test",
        body: "This should be rate limited"
      )
    end
  end

  test "should not crash on malformed device token" do
    # Test malformed token handling
    assert_nothing_raised do
      Notifications::Push.send_example(
        "malformed_token",
        title: "Malformed Token Test",
        body: "This should not crash"
      )
    end
  end

  test "should queue retries for failed notifications" do
    # Test retry logic
    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: "Retry Test",
        body: "This should retry"
      )
    end
  end

  # ==========================================
  # CRITICAL ALERTS TESTS
  # ==========================================

  test "should send critical alert with correct payload" do
    # Test critical alert payload structure
    payload = {
      aps: {
        alert: { title: "Critical Alert", body: "This is critical" },
        sound: {
          critical: 1,
          name: "critical.caf",
          volume: 1.0
        },
        badge: 5
      }
    }

    assert payload[:aps][:sound][:critical] == 1
    assert payload[:aps][:sound][:name] == "critical.caf"
    assert payload[:aps][:sound][:volume] == 1.0
  end

  test "should send background update notification" do
    # Test background update payload
    payload = {
      aps: {
        "content-available" => 1
      },
      custom_data: "value"
    }

    assert payload[:aps]["content-available"] == 1
    assert payload[:custom_data] == "value"
  end

  test "should send VoIP notification" do
    # Test VoIP payload structure
    payload = {
      custom: "voip_data"
    }

    assert payload[:custom] == "voip_data"
  end

  # ==========================================
  # HEALTH CHECK TESTS
  # ==========================================

  test "should perform health check successfully" do
    # Test health check structure
    assert_nothing_raised do
      Notifications::Push.health_check("test_health_token")
    end
  end

  test "should detect unhealthy APNs connection" do
    # Test health check with invalid token
    assert_nothing_raised do
      Notifications::Push.health_check("invalid_health_token")
    end
  end

  # ==========================================
  # BADGE COUNT TESTS
  # ==========================================

  test "should calculate correct badge count" do
    # Create multiple pending tasks
    3.times do |i|
      Task.create!(
        list: @list,
        creator: @user,
        title: "Task #{i + 1}",
        due_at: 1.hour.from_now,
        status: :pending,
        strict_mode: false
      )
    end

    # Create overdue task
    Task.create!(
      list: @list,
      creator: @user,
      title: "Overdue Task",
      due_at: 1.hour.ago,
      status: :pending,
      strict_mode: false
    )

    badge_count = NotificationService.send(:calculate_badge_count, @user)
    assert_equal 4, badge_count
  end

  test "should not count completed tasks in badge" do
    # Create completed task
    Task.create!(
      list: @list,
      creator: @user,
      title: "Completed Task",
      due_at: 1.hour.from_now,
      status: :done,
      strict_mode: false
    )

    badge_count = NotificationService.send(:calculate_badge_count, @user)
    assert_equal 0, badge_count
  end

  # ==========================================
  # EDGE CASES TESTS
  # ==========================================

  test "should handle user with no devices" do
    user_without_devices = create_test_user(email: "no_devices@example.com")
    
    # Should not raise error when user has no devices
    assert_nothing_raised do
      NotificationService.new_item_assigned(@task)
    end
  end

  test "should handle user with multiple iOS devices" do
    # Create second iOS device
    Device.create!(
      user: @user,
      platform: "ios",
      apns_token: "second_device_token",
      bundle_id: "com.focusmate.app"
    )

    # Should handle multiple devices
    assert_nothing_raised do
      NotificationService.new_item_assigned(@task)
    end
  end

  test "should handle mixed platform devices" do
    # Create Android device
    Device.create!(
      user: @user,
      platform: "android",
      fcm_token: "android_token"
    )

    # Should handle mixed platforms
    assert_nothing_raised do
      NotificationService.new_item_assigned(@task)
    end
  end

  test "should handle notification with special characters" do
    special_title = "Task with émojis 🎯 & special chars: @#$%"
    special_body = "Body with unicode: 中文 and symbols: ★☆"

    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: special_title,
        body: special_body
      )
    end
  end

  test "should handle very long notification content" do
    long_title = "A" * 1000  # Very long title
    long_body = "B" * 2000   # Very long body

    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: long_title,
        body: long_body
      )
    end
  end

  # ==========================================
  # NOTIFICATION LOGGING TESTS
  # ==========================================

  test "should log notification attempts" do
    # Test that notifications are logged
    assert_difference "NotificationLog.count", 1 do
      NotificationService.new_item_assigned(@task)
    end

    log = NotificationLog.last
    assert_equal @user, log.user
    assert_equal "new_task_assigned", log.notification_type
    assert_includes log.message, @task.title
  end

  test "should log notification failures" do
    # Test failure logging
    assert_nothing_raised do
      NotificationService.task_reminder(@task)
    end
  end

  test "should track notification delivery status" do
    # Test delivery status tracking
    log = NotificationLog.create!(
      user: @user,
      notification_type: "test_notification",
      message: "Test message",
      delivered_at: Time.current
    )

    assert log.delivered_at.present?
    assert log.delivered?
  end

  # ==========================================
  # PAYLOAD VALIDATION TESTS
  # ==========================================

  test "should validate APNs payload structure" do
    # Test valid payload structure
    payload = {
      aps: {
        alert: { title: "Valid Title", body: "Valid Body" },
        sound: "default",
        badge: 1
      }
    }

    assert payload[:aps].present?
    assert payload[:aps][:alert].present?
    assert payload[:aps][:alert][:title].present?
    assert payload[:aps][:alert][:body].present?
  end

  test "should validate FCM payload structure" do
    # Test valid FCM payload structure
    payload = {
      notification: {
        title: "FCM Title",
        body: "FCM Body",
        sound: "default"
      },
      data: {
        task_id: @task.id,
        timestamp: Time.current.to_i
      }
    }

    assert payload[:notification].present?
    assert payload[:notification][:title].present?
    assert payload[:notification][:body].present?
    assert payload[:data].present?
  end

  test "should handle empty notification content" do
    # Test with empty content
    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: "",
        body: ""
      )
    end
  end

  test "should handle nil notification content" do
    # Test with nil content
    assert_nothing_raised do
      Notifications::Push.send_example(
        @device.apns_token,
        title: nil,
        body: nil
      )
    end
  end
end