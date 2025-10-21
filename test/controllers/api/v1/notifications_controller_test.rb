require "test_helper"

class Api::V1::NotificationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(email: "user_#{SecureRandom.hex(4)}@example.com")
    @other_user = create_test_user(email: "other_#{SecureRandom.hex(4)}@example.com")
    
    @notification1 = NotificationLog.create!(
      user: @user,
      notification_type: "task_reminder",
      message: "Your task is due soon",
      metadata: { read: false, priority: "high" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    @notification2 = NotificationLog.create!(
      user: @user,
      notification_type: "task_completed",
      message: "Your task has been completed",
      metadata: { read: true, priority: "medium" },
      delivered: true,
      delivered_at: 2.hours.ago
    )
    
    @notification3 = NotificationLog.create!(
      user: @user,
      notification_type: "list_shared",
      message: "A list has been shared with you",
      metadata: { read: false, priority: "low" },
      delivered: true,
      delivered_at: 3.hours.ago
    )
    
    @other_user_notification = NotificationLog.create!(
      user: @other_user,
      notification_type: "task_reminder",
      message: "This is not your notification",
      metadata: { read: false, priority: "high" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    @user_headers = auth_headers(@user)
    @other_user_headers = auth_headers(@other_user)
  end

  # Index tests
  test "should get all notifications for user" do
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 3, json.length
    
    notification_ids = json.map { |n| n["id"] }
    assert_includes notification_ids, @notification1.id
    assert_includes notification_ids, @notification2.id
    assert_includes notification_ids, @notification3.id
    assert_not_includes notification_ids, @other_user_notification.id
  end

  test "should filter by read/unread" do
    # Test unread notifications
    get "/api/v1/notifications?read=false", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 2, json.length
    
    unread_ids = json.map { |n| n["id"] }
    assert_includes unread_ids, @notification1.id
    assert_includes unread_ids, @notification3.id
    assert_not_includes unread_ids, @notification2.id
    
    # Test read notifications
    get "/api/v1/notifications?read=true", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 1, json.length
    assert_equal @notification2.id, json.first["id"]
  end

  test "should paginate notifications" do
    # Create more notifications to test pagination
    10.times do |i|
      NotificationLog.create!(
        user: @user,
        notification_type: "test_notification",
        message: "This is test notification #{i}",
        metadata: { read: false },
        delivered: true,
        delivered_at: (i + 4).hours.ago
      )
    end
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 10, json.length # Should be limited to 50, but we have 13 total
  end

  test "should order by created_at descending" do
    # Create notifications with specific timestamps
    old_notification = NotificationLog.create!(
      user: @user,
      notification_type: "old_notification",
      message: "This is an old notification",
      metadata: { read: false },
      delivered: true,
      delivered_at: 5.hours.ago
    )
    
    new_notification = NotificationLog.create!(
      user: @user,
      notification_type: "new_notification",
      message: "This is a new notification",
      metadata: { read: false },
      delivered: true,
      delivered_at: 30.minutes.ago
    )
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal new_notification.id, json.first["id"]
    assert_equal old_notification.id, json.last["id"]
  end

  test "should not get notifications without authentication" do
    get "/api/v1/notifications"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should only show user's own notifications" do
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 3, json.length
    
    notification_ids = json.map { |n| n["id"] }
    assert_not_includes notification_ids, @other_user_notification.id
  end

  test "should handle empty notifications list" do
    new_user = create_test_user(email: "new_user_#{SecureRandom.hex(4)}@example.com")
    new_user_headers = auth_headers(new_user)
    
    get "/api/v1/notifications", headers: new_user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 0, json.length
  end

  test "should include notification details" do
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 3, json.length
    
    first_notification = json.first
    assert_includes first_notification.keys, "id"
    assert_includes first_notification.keys, "message"
    assert_includes first_notification.keys, "notification_type"
    assert_includes first_notification.keys, "metadata"
    assert_includes first_notification.keys, "delivered_at"
  end

  # Mark Read tests
  test "should mark single notification as read" do
    patch "/api/v1/notifications/#{@notification1.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    assert @notification1.metadata["read"]
  end

  test "should update read status" do
    assert_not @notification1.metadata["read"]
    
    patch "/api/v1/notifications/#{@notification1.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    assert @notification1.metadata["read"]
  end

  test "should return 404 if not user's notification" do
    patch "/api/v1/notifications/#{@other_user_notification.id}/mark_read", headers: @user_headers
    
    assert_error_response(response, :not_found, "Notification not found")
  end

  test "should not mark notification as read without authentication" do
    patch "/api/v1/notifications/#{@notification1.id}/mark_read"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle marking already read notification" do
    # @notification2 is already read
    patch "/api/v1/notifications/#{@notification2.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification2.reload
    assert @notification2.metadata["read"]
  end

  test "should handle non-existent notification" do
    patch "/api/v1/notifications/99999/mark_read", headers: @user_headers
    
    assert_error_response(response, :not_found, "Notification not found")
  end

  test "should preserve other metadata when marking as read" do
    original_metadata = @notification1.metadata.dup
    
    patch "/api/v1/notifications/#{@notification1.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    assert @notification1.metadata["read"]
    assert_equal original_metadata["priority"], @notification1.metadata["priority"]
  end

  # Mark All Read tests
  test "should mark all notifications as read" do
    patch "/api/v1/notifications/mark_all_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    @notification2.reload
    @notification3.reload
    
    assert @notification1.metadata["read"]
    assert @notification2.metadata["read"] # Was already read
    assert @notification3.metadata["read"]
  end

  test "should only affect current user's notifications" do
    patch "/api/v1/notifications/mark_all_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    @notification2.reload
    @notification3.reload
    @other_user_notification.reload
    
    assert @notification1.metadata["read"]
    assert @notification2.metadata["read"]
    assert @notification3.metadata["read"]
    assert_not @other_user_notification.metadata["read"]
  end

  test "should not mark all notifications as read without authentication" do
    patch "/api/v1/notifications/mark_all_read"
    
    assert_error_response(response, :unauthorized, "Authorization token required")
  end

  test "should handle user with no notifications" do
    new_user = create_test_user(email: "no_notifications_#{SecureRandom.hex(4)}@example.com")
    new_user_headers = auth_headers(new_user)
    
    patch "/api/v1/notifications/mark_all_read", headers: new_user_headers
    
    assert_response :no_content
  end

  test "should handle user with all notifications already read" do
    # Mark all notifications as read first
    @user.notification_logs.update_all(metadata: { read: true })
    
    patch "/api/v1/notifications/mark_all_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    @notification2.reload
    @notification3.reload
    
    assert @notification1.metadata["read"]
    assert @notification2.metadata["read"]
    assert @notification3.metadata["read"]
  end

  test "should preserve other metadata when marking all as read" do
    original_metadata1 = @notification1.metadata.dup
    original_metadata3 = @notification3.metadata.dup
    
    patch "/api/v1/notifications/mark_all_read", headers: @user_headers
    
    assert_response :no_content
    
    @notification1.reload
    @notification3.reload
    
    assert @notification1.metadata["read"]
    assert @notification3.metadata["read"]
    assert_equal original_metadata1["priority"], @notification1.metadata["priority"]
    assert_equal original_metadata3["priority"], @notification3.metadata["priority"]
  end

  # Edge cases
  test "should handle malformed JSON" do
    patch "/api/v1/notifications/#{@notification1.id}/mark_read", 
          params: "invalid json",
          headers: @user_headers.merge("Content-Type" => "application/json")
    
    assert_response :no_content
  end

  test "should handle very large notification lists" do
    # Create many notifications
    100.times do |i|
      NotificationLog.create!(
        user: @user,
        notification_type: "bulk_notification",
        message: "This is bulk notification #{i}",
        metadata: { read: false },
        delivered: true,
        delivered_at: (i + 1).hours.ago
      )
    end
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    assert_equal 50, json.length # Should be limited to 50
  end

  test "should handle notifications with complex metadata" do
    complex_notification = NotificationLog.create!(
      user: @user,
      notification_type: "complex_notification",
      message: "This notification has complex metadata",
      metadata: {
        read: false,
        priority: "high",
        category: "urgent",
        tags: ["important", "urgent"],
        data: {
          task_id: 123,
          list_id: 456,
          user_id: @user.id
        }
      },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    complex_notification_json = json.find { |n| n["id"] == complex_notification.id }
    assert_not_nil complex_notification_json
    assert_equal "high", complex_notification_json["metadata"]["priority"]
    assert_equal "urgent", complex_notification_json["metadata"]["category"]
    assert_includes complex_notification_json["metadata"]["tags"], "important"
  end

  test "should handle notifications with nil metadata" do
    nil_metadata_notification = NotificationLog.create!(
      user: @user,
      notification_type: "nil_metadata",
      message: "This notification has nil metadata",
      metadata: nil,
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    patch "/api/v1/notifications/#{nil_metadata_notification.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    nil_metadata_notification.reload
    assert_not_nil nil_metadata_notification.metadata
    assert nil_metadata_notification.metadata["read"]
  end

  test "should handle notifications with empty metadata" do
    empty_metadata_notification = NotificationLog.create!(
      user: @user,
      notification_type: "empty_metadata",
      message: "This notification has empty metadata",
      metadata: {},
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    patch "/api/v1/notifications/#{empty_metadata_notification.id}/mark_read", headers: @user_headers
    
    assert_response :no_content
    
    empty_metadata_notification.reload
    assert empty_metadata_notification.metadata["read"]
  end

  test "should handle concurrent mark read operations" do
    threads = []
    3.times do
      threads << Thread.new do
        patch "/api/v1/notifications/#{@notification1.id}/mark_read", headers: @user_headers
      end
    end
    
    threads.each(&:join)
    
    @notification1.reload
    assert @notification1.metadata["read"]
  end

  test "should handle concurrent mark all read operations" do
    threads = []
    3.times do
      threads << Thread.new do
        patch "/api/v1/notifications/mark_all_read", headers: @user_headers
      end
    end
    
    threads.each(&:join)
    
    @notification1.reload
    @notification3.reload
    assert @notification1.metadata["read"]
    assert @notification3.metadata["read"]
  end

  test "should handle notifications with special characters" do
    special_notification = NotificationLog.create!(
      user: @user,
      notification_type: "special_chars",
      message: "This notification has special characters: éñ中文",
      metadata: { read: false, special: "!@#$%^&*()" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    special_notification_json = json.find { |n| n["id"] == special_notification.id }
    assert_not_nil special_notification_json
    assert_equal "This notification has special characters: éñ中文", special_notification_json["message"]
  end

  test "should handle notifications with very long content" do
    long_title = "A" * 1000
    long_message = "B" * 5000
    
    long_notification = NotificationLog.create!(
      user: @user,
      notification_type: "long_content",
      message: long_message,
      metadata: { read: false },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    long_notification_json = json.find { |n| n["id"] == long_notification.id }
    assert_not_nil long_notification_json
    assert_equal long_message, long_notification_json["message"]
  end

  test "should handle notifications with unicode content" do
    unicode_notification = NotificationLog.create!(
      user: @user,
      notification_type: "unicode",
      message: "This notification contains emojis: 🎉🎊🎈",
      metadata: { read: false, emoji: "🚀" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
    
    get "/api/v1/notifications", headers: @user_headers
    
    assert_response :success
    json = assert_json_response(response)
    
    assert json.is_a?(Array)
    unicode_notification_json = json.find { |n| n["id"] == unicode_notification.id }
    assert_not_nil unicode_notification_json
    assert_equal "This notification contains emojis: 🎉🎊🎈", unicode_notification_json["message"]
  end
end
