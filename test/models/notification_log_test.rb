require "test_helper"

class NotificationLogTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
    @list = create_test_list(@user)
    @task = create_test_task(@list, creator: @user)
    @notification_log = NotificationLog.new(
      user: @user,
      task: @task,
      notification_type: "task_reminder",
      message: "Your task is due soon",
      delivered: false
    )
  end

  test "should belong to user" do
    assert @notification_log.valid?
    assert_equal @user, @notification_log.user
  end

  test "should optionally belong to task" do
    # Test with task
    assert @notification_log.valid?
    assert_equal @task, @notification_log.task

    # Test without task
    notification_without_task = NotificationLog.new(
      user: @user,
      notification_type: "system_announcement",
      message: "System maintenance scheduled"
    )
    assert notification_without_task.valid?
    assert_nil notification_without_task.task
  end

  test "should require notification_type" do
    @notification_log.notification_type = nil
    assert_not @notification_log.valid?
    assert_includes @notification_log.errors[:notification_type], "can't be blank"
  end

  test "should default delivered to false" do
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Test notification"
    )
    assert_equal false, notification.delivered
  end

  test "should record delivered_at when delivered" do
    @notification_log.save!
    assert_nil @notification_log.delivered_at
    
    @notification_log.mark_delivered!
    
    assert @notification_log.delivered?
    assert_not_nil @notification_log.delivered_at
    assert @notification_log.delivered_at <= Time.current
  end

  test "should store message text" do
    message = "Your task 'Complete project' is due in 1 hour"
    @notification_log.message = message
    @notification_log.save!
    
    assert_equal message, @notification_log.message
  end

  test "should store metadata as JSONB" do
    metadata = {
      device_id: "device_123",
      push_response: "success",
      retry_count: 0,
      error_message: nil
    }
    
    @notification_log.metadata = metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "device_id" => "device_123",
      "push_response" => "success",
      "retry_count" => 0,
      "error_message" => nil
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
    assert @notification_log.metadata.is_a?(String)
  end

  test "should track notification_type" do
    notification_types = %w[
      task_reminder
      task_overdue
      task_due_soon
      task_completed
      task_escalated
      coaching_invitation
      system_announcement
      daily_summary
    ]
    
    notification_types.each do |type|
      notification = NotificationLog.new(
        user: @user,
        notification_type: type,
        message: "Test #{type} notification"
      )
      assert notification.valid?, "Notification type '#{type}' should be valid"
    end
  end

  test "should count undelivered notifications" do
    # Create delivered notification
    delivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Delivered notification",
      delivered: true
    )
    
    # Create undelivered notification
    undelivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "Undelivered notification",
      delivered: false
    )
    
    undelivered_count = NotificationLog.undelivered.count
    assert_equal 1, undelivered_count
    assert_includes NotificationLog.undelivered, undelivered_notification
    assert_not_includes NotificationLog.undelivered, delivered_notification
  end

  test "should retry failed notifications" do
    # Create notification with retry metadata
    retry_metadata = {
      retry_count: 2,
      last_retry_at: 1.hour.ago,
      error_message: "Push service unavailable"
    }
    
    @notification_log.metadata = retry_metadata
    @notification_log.save!
    
    assert_equal 2, @notification_log.parsed_metadata["retry_count"]
    assert_equal "Push service unavailable", @notification_log.parsed_metadata["error_message"]
  end

  test "should use delivered scope" do
    delivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Delivered notification",
      delivered: true
    )
    
    undelivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "Undelivered notification",
      delivered: false
    )
    
    delivered_notifications = NotificationLog.delivered
    assert_includes delivered_notifications, delivered_notification
    assert_not_includes delivered_notifications, undelivered_notification
  end

  test "should use undelivered scope" do
    delivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Delivered notification",
      delivered: true
    )
    
    undelivered_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "Undelivered notification",
      delivered: false
    )
    
    undelivered_notifications = NotificationLog.undelivered
    assert_includes undelivered_notifications, undelivered_notification
    assert_not_includes undelivered_notifications, delivered_notification
  end

  test "should use by_type scope" do
    reminder_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Reminder notification"
    )
    
    overdue_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "Overdue notification"
    )
    
    reminder_notifications = NotificationLog.by_type("task_reminder")
    assert_includes reminder_notifications, reminder_notification
    assert_not_includes reminder_notifications, overdue_notification
  end

  test "should use recent scope" do
    old_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Old notification",
      created_at: 2.days.ago
    )
    
    recent_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "Recent notification"
    )
    
    recent_notifications = NotificationLog.recent
    assert_equal recent_notification, recent_notifications.first
    assert_equal old_notification, recent_notifications.last
  end

  test "should check if notification was delivered" do
    @notification_log.delivered = false
    assert_not @notification_log.delivered?
    
    @notification_log.delivered = true
    assert @notification_log.delivered?
  end

  test "should mark as delivered" do
    @notification_log.save!
    assert_not @notification_log.delivered?
    assert_nil @notification_log.delivered_at
    
    @notification_log.mark_delivered!
    
    assert @notification_log.delivered?
    assert_not_nil @notification_log.delivered_at
    assert @notification_log.delivered_at <= Time.current
  end

  test "should handle nil metadata" do
    @notification_log.metadata = nil
    @notification_log.save!
    
    assert_equal({}, @notification_log.metadata)
    assert_equal({}, @notification_log.parsed_metadata)
  end

  test "should handle empty metadata" do
    @notification_log.metadata = ""
    @notification_log.save!
    
    assert_equal({}, @notification_log.metadata)
    assert_equal({}, @notification_log.parsed_metadata)
  end

  test "should handle invalid JSON in metadata" do
    @notification_log.save!
    
    # Directly set invalid JSON in the database
    @notification_log.update_column(:metadata, "invalid json")
    
    assert_equal({}, @notification_log.parsed_metadata)
  end

  test "should check if notification is read" do
    @notification_log.metadata = { "read" => false }
    @notification_log.save!
    
    assert_not @notification_log.read?
    
    @notification_log.metadata = { "read" => true }
    @notification_log.save!
    
    assert @notification_log.read?
  end

  test "should mark as read" do
    @notification_log.metadata = { "read" => false, "other_data" => "value" }
    @notification_log.save!
    
    @notification_log.mark_read!
    
    assert @notification_log.read?
    assert_equal "value", @notification_log.parsed_metadata["other_data"]
  end

  test "should get notification summary" do
    @notification_log.metadata = { "read" => true }
    @notification_log.save!
    
    summary = @notification_log.summary
    
    assert_equal @notification_log.id, summary[:id]
    assert_equal "task_reminder", summary[:type]
    assert_equal "Your task is due soon", summary[:message]
    assert_equal false, summary[:delivered]
    assert_equal true, summary[:read]
    assert_equal @notification_log.created_at, summary[:created_at]
  end

  test "should get notification details" do
    @notification_log.metadata = { "read" => true, "device_id" => "device_123" }
    @notification_log.save!
    
    details = @notification_log.details
    
    assert_equal @notification_log.id, details[:id]
    assert_equal "task_reminder", details[:type]
    assert_equal "Your task is due soon", details[:message]
    assert_equal false, details[:delivered]
    assert_nil details[:delivered_at]
    assert_equal true, details[:read]
    assert_not_nil details[:task]
    assert_equal @task.id, details[:task][:id]
    assert_equal @task.title, details[:task][:title]
    assert_equal @task.due_at, details[:task][:due_at]
    assert_equal @task.status, details[:task][:status]
    assert_equal({ "read" => true, "device_id" => "device_123" }, details[:metadata])
    assert_equal @notification_log.created_at, details[:created_at]
    assert_equal @notification_log.updated_at, details[:updated_at]
  end

  test "should get notification age in hours" do
    @notification_log.created_at = 2.hours.ago
    @notification_log.save!
    
    age = @notification_log.age_hours
    assert age >= 1.9
    assert age <= 2.1
  end

  test "should check if notification is recent" do
    @notification_log.created_at = 1.hour.ago
    @notification_log.save!
    
    assert @notification_log.recent?
    
    @notification_log.created_at = 25.hours.ago
    @notification_log.save!
    
    assert_not @notification_log.recent?
  end

  test "should get notification priority" do
    high_priority_types = %w[task_overdue task_escalated]
    medium_priority_types = %w[task_due_soon coaching_invitation]
    low_priority_types = %w[task_reminder system_announcement daily_summary]
    
    high_priority_types.each do |type|
      @notification_log.notification_type = type
      assert_equal "high", @notification_log.priority
    end
    
    medium_priority_types.each do |type|
      @notification_log.notification_type = type
      assert_equal "medium", @notification_log.priority
    end
    
    low_priority_types.each do |type|
      @notification_log.notification_type = type
      assert_equal "low", @notification_log.priority
    end
  end

  test "should handle complex metadata" do
    complex_metadata = {
      device_id: "device_123",
      push_response: {
        status: "success",
        message_id: "msg_456",
        timestamp: Time.current.iso8601
      },
      retry_count: 3,
      error_history: [
        { error: "Network timeout", timestamp: 1.hour.ago.iso8601 },
        { error: "Service unavailable", timestamp: 30.minutes.ago.iso8601 }
      ],
      user_preferences: {
        push_enabled: true,
        quiet_hours: "22:00-08:00"
      }
    }
    
    @notification_log.metadata = complex_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "device_id" => "device_123",
      "push_response" => {
        "status" => "success",
        "message_id" => "msg_456",
        "timestamp" => Time.current.iso8601
      },
      "retry_count" => 3,
      "error_history" => [
        { "error" => "Network timeout", "timestamp" => 1.hour.ago.iso8601 },
        { "error" => "Service unavailable", "timestamp" => 30.minutes.ago.iso8601 }
      ],
      "user_preferences" => {
        "push_enabled" => true,
        "quiet_hours" => "22:00-08:00"
      }
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle metadata with special characters" do
    special_metadata = {
      message: "Task with émojis 🎯 and special chars: @#$%",
      unicode_text: "中文, العربية, русский, 日本語, 한국어",
      symbols: "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    }
    
    @notification_log.metadata = special_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "message" => "Task with émojis 🎯 and special chars: @#$%",
      "unicode_text" => "中文, العربية, русский, 日本語, 한국어",
      "symbols" => "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle metadata with arrays and nested objects" do
    nested_metadata = {
      recipients: ["user1@example.com", "user2@example.com"],
      channels: [
        { type: "push", status: "sent" },
        { type: "email", status: "pending" }
      ],
      settings: {
        priority: "high",
        retry_policy: {
          max_retries: 3,
          backoff: "exponential"
        }
      }
    }
    
    @notification_log.metadata = nested_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "recipients" => ["user1@example.com", "user2@example.com"],
      "channels" => [
        { "type" => "push", "status" => "sent" },
        { "type" => "email", "status" => "pending" }
      ],
      "settings" => {
        "priority" => "high",
        "retry_policy" => {
          "max_retries" => 3,
          "backoff" => "exponential"
        }
      }
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle notification without task" do
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "system_announcement",
      message: "System maintenance scheduled",
      metadata: { "announcement_type" => "maintenance" }
    )
    
    details = notification.details
    assert_nil details[:task]
    assert_equal "system_announcement", details[:type]
    assert_equal "System maintenance scheduled", details[:message]
  end

  test "should handle notification with long message" do
    long_message = "This is a very long notification message that contains detailed information about the task, including all the necessary context and instructions for the user to understand what needs to be done and when it needs to be completed. " * 10
    
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: long_message
    )
    
    assert notification.valid?
    assert_equal long_message, notification.message
  end

  test "should handle notification with multiline message" do
    multiline_message = "Task Reminder:\n\nYour task 'Complete project' is due in 1 hour.\n\nPlease ensure you have all necessary resources.\n\nGood luck!"
    
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: multiline_message
    )
    
    assert notification.valid?
    assert_equal multiline_message, notification.message
  end

  test "should handle notification with empty message" do
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: ""
    )
    
    assert notification.valid?
    assert_equal "", notification.message
  end

  test "should handle notification with nil message" do
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: nil
    )
    
    assert notification.valid?
    assert_nil notification.message
  end

  test "should handle notification with very old created_at" do
    old_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Old notification",
      created_at: 1.year.ago
    )
    
    assert_not old_notification.recent?
    assert old_notification.age_hours > 8000 # More than 1 year in hours
  end

  test "should handle notification with future created_at" do
    future_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Future notification",
      created_at: 1.hour.from_now
    )
    
    assert future_notification.recent?
    assert future_notification.age_hours < 0 # Negative age for future timestamps
  end

  test "should handle notification with different users" do
    other_user = create_test_user
    
    user1_notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "User 1 notification"
    )
    
    user2_notification = NotificationLog.create!(
      user: other_user,
      notification_type: "task_reminder",
      message: "User 2 notification"
    )
    
    assert_equal @user, user1_notification.user
    assert_equal other_user, user2_notification.user
    assert_equal 1, @user.notification_logs.count
    assert_equal 1, other_user.notification_logs.count
  end

  test "should handle notification with multiple tasks" do
    task2 = create_test_task(@list, creator: @user)
    
    notification1 = NotificationLog.create!(
      user: @user,
      task: @task,
      notification_type: "task_reminder",
      message: "Task 1 reminder"
    )
    
    notification2 = NotificationLog.create!(
      user: @user,
      task: task2,
      notification_type: "task_reminder",
      message: "Task 2 reminder"
    )
    
    assert_equal @task, notification1.task
    assert_equal task2, notification2.task
    assert_equal 1, @task.notification_logs.count
    assert_equal 1, task2.notification_logs.count
  end

  test "should handle notification with boolean metadata" do
    boolean_metadata = {
      read: true,
      delivered: false,
      push_enabled: true,
      email_enabled: false
    }
    
    @notification_log.metadata = boolean_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "read" => true,
      "delivered" => false,
      "push_enabled" => true,
      "email_enabled" => false
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle notification with numeric metadata" do
    numeric_metadata = {
      retry_count: 5,
      priority: 1,
      delay_seconds: 300,
      score: 85.5
    }
    
    @notification_log.metadata = numeric_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "retry_count" => 5,
      "priority" => 1,
      "delay_seconds" => 300,
      "score" => 85.5
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle notification with mixed metadata types" do
    mixed_metadata = {
      string_value: "test",
      number_value: 42,
      boolean_value: true,
      array_value: [1, 2, 3],
      object_value: { nested: "data" },
      null_value: nil
    }
    
    @notification_log.metadata = mixed_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "string_value" => "test",
      "number_value" => 42,
      "boolean_value" => true,
      "array_value" => [1, 2, 3],
      "object_value" => { "nested" => "data" },
      "null_value" => nil
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle notification with very large metadata" do
    large_metadata = {
      large_text: "a" * 1000,
      large_array: (1..100).map { |i| "item_#{i}" },
      large_object: (1..50).map { |i| { "key_#{i}" => "value_#{i}" } }.reduce({}, :merge)
    }
    
    @notification_log.metadata = large_metadata
    @notification_log.save!
    
    # JSON parsing returns string keys, not symbol keys
    expected_metadata = {
      "large_text" => "a" * 1000,
      "large_array" => (1..100).map { |i| "item_#{i}" },
      "large_object" => (1..50).map { |i| { "key_#{i}" => "value_#{i}" } }.reduce({}, :merge)
    }
    assert_equal expected_metadata, @notification_log.parsed_metadata
  end

  test "should handle notification with unicode in message" do
    unicode_message = "Task with émojis 🎯 and special chars: @#$% and unicode: 中文, العربية, русский, 日本語, 한국어"
    
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: unicode_message
    )
    
    assert notification.valid?
    assert_equal unicode_message, notification.message
  end

  test "should handle notification with tab characters in message" do
    tab_message = "Task reminder:\tPlease complete the following:\n1. Review requirements\n2. Implement solution\n3. Test thoroughly"
    
    notification = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: tab_message
    )
    
    assert notification.valid?
    assert_equal tab_message, notification.message
  end

  test "should handle notification with all notification types" do
    all_types = %w[
      task_reminder
      task_overdue
      task_due_soon
      task_completed
      task_escalated
      coaching_invitation
      system_announcement
      daily_summary
      task_reassigned
      task_created
      task_updated
      task_deleted
    ]
    
    all_types.each do |type|
      notification = NotificationLog.create!(
        user: @user,
        notification_type: type,
        message: "Test #{type} notification"
      )
      
      assert notification.valid?
      assert_equal type, notification.notification_type
    end
  end

  test "should handle notification with all priority levels" do
    high_priority = NotificationLog.create!(
      user: @user,
      notification_type: "task_overdue",
      message: "High priority notification"
    )
    
    medium_priority = NotificationLog.create!(
      user: @user,
      notification_type: "task_due_soon",
      message: "Medium priority notification"
    )
    
    low_priority = NotificationLog.create!(
      user: @user,
      notification_type: "system_announcement",
      message: "Low priority notification"
    )
    
    assert_equal "high", high_priority.priority
    assert_equal "medium", medium_priority.priority
    assert_equal "low", low_priority.priority
  end
end
