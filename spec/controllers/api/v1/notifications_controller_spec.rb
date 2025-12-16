require "rails_helper"

RSpec.describe Api::V1::NotificationsController, type: :request do
  let(:user) { create(:user, email: "user_#{SecureRandom.hex(4)}@example.com") }
  let(:other_user) { create(:user, email: "other_#{SecureRandom.hex(4)}@example.com") }

  let(:notification1) do
    NotificationLog.create!(
      user: user,
      notification_type: "task_reminder",
      message: "Your task is due soon",
      metadata: { read: false, priority: "high" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
  end

  let(:notification2) do
    NotificationLog.create!(
      user: user,
      notification_type: "task_reminder",
      message: "Your task has been completed",
      metadata: { read: true, priority: "medium" },
      delivered: true,
      delivered_at: 2.hours.ago
    )
  end

  let(:notification3) do
    NotificationLog.create!(
      user: user,
      notification_type: "coaching_message",
      message: "A list has been shared with you",
      metadata: { read: false, priority: "low" },
      delivered: true,
      delivered_at: 3.hours.ago
    )
  end

  let(:other_user_notification) do
    NotificationLog.create!(
      user: other_user,
      notification_type: "task_reminder",
      message: "This is not your notification",
      metadata: { read: false, priority: "high" },
      delivered: true,
      delivered_at: 1.hour.ago
    )
  end

  let(:user_headers) { auth_headers(user) }
  let(:other_user_headers) { auth_headers(other_user) }

  describe "GET /api/v1/notifications" do
    it "should get all notifications for user" do
      # Ensure notifications are created
      notification1
      notification2
      notification3
      other_user_notification

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(3)

      notification_ids = json.map { |n| n["id"] }
      expect(notification_ids).to include(notification1.id)
      expect(notification_ids).to include(notification2.id)
      expect(notification_ids).to include(notification3.id)
      expect(notification_ids).not_to include(other_user_notification.id)
    end

    it "should filter by read/unread" do
      # Ensure notifications are created
      notification1
      notification2
      notification3

      # Test unread notifications
      get "/api/v1/notifications?read=false", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(2)

      unread_ids = json.map { |n| n["id"] }
      expect(unread_ids).to include(notification1.id)
      expect(unread_ids).to include(notification3.id)
      expect(unread_ids).not_to include(notification2.id)

      # Test read notifications
      get "/api/v1/notifications?read=true", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(1)
      expect(json.first["id"]).to eq(notification2.id)
    end

    it "should paginate notifications" do
      # Create more notifications to test pagination
      10.times do |i|
        NotificationLog.create!(
          user: user,
          notification_type: "test_notification",
          message: "This is test notification #{i}",
          metadata: { read: false },
          delivered: true,
          delivered_at: (i + 4).hours.ago
        )
      end

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(10) # Should be limited to 50, but we have 13 total
    end

    it "should order by created_at descending" do
      # Create notifications with specific timestamps
      old_notification = NotificationLog.create!(
        user: user,
        notification_type: "old_notification",
        message: "This is an old notification",
        metadata: { read: false },
        delivered: true,
        delivered_at: 5.hours.ago
      )

      new_notification = NotificationLog.create!(
        user: user,
        notification_type: "new_notification",
        message: "This is a new notification",
        metadata: { read: false },
        delivered: true,
        delivered_at: 30.minutes.ago
      )

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.first["id"]).to eq(new_notification.id)
      expect(json.last["id"]).to eq(old_notification.id)
    end

    it "should not get notifications without authentication" do
      get "/api/v1/notifications"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should only show user's own notifications" do
      # Ensure notifications are created
      notification1
      notification2
      notification3
      other_user_notification

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(3)

      notification_ids = json.map { |n| n["id"] }
      expect(notification_ids).not_to include(other_user_notification.id)
    end

    it "should handle empty notifications list" do
      new_user = create(:user, email: "new_user_#{SecureRandom.hex(4)}@example.com")
      new_user_headers = auth_headers(new_user)

      get "/api/v1/notifications", headers: new_user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(0)
    end

    it "should include notification details" do
      # Ensure notifications are created
      notification1
      notification2
      notification3

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(3)

      first_notification = json.first
      expect(first_notification).to have_key("id")
      expect(first_notification).to have_key("message")
      expect(first_notification).to have_key("notification_type")
      expect(first_notification).to have_key("metadata")
      expect(first_notification).to have_key("delivered_at")
    end
  end

  describe "PATCH /api/v1/notifications/:id/mark_read" do
    it "should mark single notification as read" do
      patch "/api/v1/notifications/#{notification1.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      expect(notification1.metadata["read"]).to be_truthy
    end

    it "should update read status" do
      expect(notification1.metadata["read"]).to be_falsy

      patch "/api/v1/notifications/#{notification1.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      expect(notification1.metadata["read"]).to be_truthy
    end

    it "should return 404 if not user's notification" do
      patch "/api/v1/notifications/#{other_user_notification.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Resource not found")
    end

    it "should not mark notification as read without authentication" do
      patch "/api/v1/notifications/#{notification1.id}/mark_read"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle marking already read notification" do
      # notification2 is already read
      patch "/api/v1/notifications/#{notification2.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification2.reload
      expect(notification2.metadata["read"]).to be_truthy
    end

    it "should handle non-existent notification" do
      patch "/api/v1/notifications/99999/mark_read", headers: user_headers

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Resource not found")
    end

    it "should preserve other metadata when marking as read" do
      original_metadata = notification1.metadata.dup

      patch "/api/v1/notifications/#{notification1.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      expect(notification1.metadata["read"]).to be_truthy
      expect(notification1.metadata["priority"]).to eq(original_metadata["priority"])
    end
  end

  describe "PATCH /api/v1/notifications/mark_all_read" do
    it "should mark all notifications as read" do
      # Ensure notifications are created
      notification1
      notification2
      notification3

      patch "/api/v1/notifications/mark_all_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      notification2.reload
      notification3.reload

      expect(notification1.metadata["read"]).to be_truthy
      expect(notification2.metadata["read"]).to be_truthy # Was already read
      expect(notification3.metadata["read"]).to be_truthy
    end

    it "should only affect current user's notifications" do
      # Ensure notifications are created
      notification1
      notification2
      notification3
      other_user_notification

      patch "/api/v1/notifications/mark_all_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      notification2.reload
      notification3.reload
      other_user_notification.reload

      expect(notification1.metadata["read"]).to be_truthy
      expect(notification2.metadata["read"]).to be_truthy
      expect(notification3.metadata["read"]).to be_truthy
      expect(other_user_notification.metadata["read"]).to be_falsy
    end

    it "should not mark all notifications as read without authentication" do
      patch "/api/v1/notifications/mark_all_read"

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]["message"]).to eq("Authorization token required")
    end

    it "should handle user with no notifications" do
      new_user = create(:user, email: "no_notifications_#{SecureRandom.hex(4)}@example.com")
      new_user_headers = auth_headers(new_user)

      patch "/api/v1/notifications/mark_all_read", headers: new_user_headers

      expect(response).to have_http_status(:no_content)
    end

    it "should handle user with all notifications already read" do
      # Ensure notifications are created
      notification1
      notification2
      notification3

      # Mark all notifications as read first
      user.notification_logs.update_all(metadata: { read: true })

      patch "/api/v1/notifications/mark_all_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      notification2.reload
      notification3.reload

      expect(notification1.metadata["read"]).to be_truthy
      expect(notification2.metadata["read"]).to be_truthy
      expect(notification3.metadata["read"]).to be_truthy
    end

    it "should preserve other metadata when marking all as read" do
      # Ensure notifications are created
      notification1
      notification3

      original_metadata1 = notification1.metadata.dup
      original_metadata3 = notification3.metadata.dup

      patch "/api/v1/notifications/mark_all_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      notification1.reload
      notification3.reload

      expect(notification1.metadata["read"]).to be_truthy
      expect(notification3.metadata["read"]).to be_truthy
      expect(notification1.metadata["priority"]).to eq(original_metadata1["priority"])
      expect(notification3.metadata["priority"]).to eq(original_metadata3["priority"])
    end
  end

  describe "Edge cases" do
    it "should handle malformed JSON" do
      # Ensure notification is created
      notification1

      patch "/api/v1/notifications/#{notification1.id}/mark_read",
            params: "invalid json",
            headers: user_headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:bad_request)
    end

    it "should handle very large notification lists" do
      # Create many notifications
      100.times do |i|
        NotificationLog.create!(
          user: user,
          notification_type: "bulk_notification",
          message: "This is bulk notification #{i}",
          metadata: { read: false },
          delivered: true,
          delivered_at: (i + 1).hours.ago
        )
      end

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      expect(json.length).to eq(50) # Should be limited to 50
    end

    it "should handle notifications with complex metadata" do
      complex_notification = NotificationLog.create!(
        user: user,
        notification_type: "complex_notification",
        message: "This notification has complex metadata",
        metadata: {
          read: false,
          priority: "high",
          category: "urgent",
          tags: [ "important", "urgent" ],
          data: {
            task_id: 123,
            list_id: 456,
            user_id: user.id
          }
        },
        delivered: true,
        delivered_at: 1.hour.ago
      )

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      complex_notification_json = json.find { |n| n["id"] == complex_notification.id }
      expect(complex_notification_json).not_to be_nil
      expect(complex_notification_json["metadata"]["priority"]).to eq("high")
      expect(complex_notification_json["metadata"]["category"]).to eq("urgent")
      expect(complex_notification_json["metadata"]["tags"]).to include("important")
    end

    it "should handle notifications with nil metadata" do
      nil_metadata_notification = NotificationLog.create!(
        user: user,
        notification_type: "nil_metadata",
        message: "This notification has nil metadata",
        metadata: nil,
        delivered: true,
        delivered_at: 1.hour.ago
      )

      patch "/api/v1/notifications/#{nil_metadata_notification.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      nil_metadata_notification.reload
      expect(nil_metadata_notification.metadata).not_to be_nil
      expect(nil_metadata_notification.metadata["read"]).to be_truthy
    end

    it "should handle notifications with empty metadata" do
      empty_metadata_notification = NotificationLog.create!(
        user: user,
        notification_type: "empty_metadata",
        message: "This notification has empty metadata",
        metadata: {},
        delivered: true,
        delivered_at: 1.hour.ago
      )

      patch "/api/v1/notifications/#{empty_metadata_notification.id}/mark_read", headers: user_headers

      expect(response).to have_http_status(:no_content)

      empty_metadata_notification.reload
      expect(empty_metadata_notification.metadata["read"]).to be_truthy
    end

    it "should handle concurrent mark read operations" do
      threads = []
      3.times do
        threads << Thread.new do
          patch "/api/v1/notifications/#{notification1.id}/mark_read", headers: user_headers
        end
      end

      threads.each(&:join)

      notification1.reload
      expect(notification1.metadata["read"]).to be_truthy
    end

    it "should handle concurrent mark all read operations" do
      # Ensure notifications are created
      notification1
      notification3

      threads = []
      3.times do
        threads << Thread.new do
          patch "/api/v1/notifications/mark_all_read", headers: user_headers
        end
      end

      threads.each(&:join)

      notification1.reload
      notification3.reload
      expect(notification1.metadata["read"]).to be_truthy
      expect(notification3.metadata["read"]).to be_truthy
    end

    it "should handle notifications with special characters" do
      special_notification = NotificationLog.create!(
        user: user,
        notification_type: "special_chars",
        message: "This notification has special characters: éñ中文",
        metadata: { read: false, special: "!@#$%^&*()" },
        delivered: true,
        delivered_at: 1.hour.ago
      )

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      special_notification_json = json.find { |n| n["id"] == special_notification.id }
      expect(special_notification_json).not_to be_nil
      expect(special_notification_json["message"]).to eq("This notification has special characters: éñ中文")
    end

    it "should handle notifications with very long content" do
      long_message = "B" * 5000

      long_notification = NotificationLog.create!(
        user: user,
        notification_type: "long_content",
        message: long_message,
        metadata: { read: false },
        delivered: true,
        delivered_at: 1.hour.ago
      )

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      long_notification_json = json.find { |n| n["id"] == long_notification.id }
      expect(long_notification_json).not_to be_nil
      expect(long_notification_json["message"]).to eq(long_message)
    end

    it "should handle notifications with unicode content" do
      unicode_notification = NotificationLog.create!(
        user: user,
        notification_type: "unicode",
        message: "This notification contains emojis: 🎉🎊🎈",
        metadata: { read: false, emoji: "🚀" },
        delivered: true,
        delivered_at: 1.hour.ago
      )

      get "/api/v1/notifications", headers: user_headers

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json).to be_a(Array)
      unicode_notification_json = json.find { |n| n["id"] == unicode_notification.id }
      expect(unicode_notification_json).not_to be_nil
      expect(unicode_notification_json["message"]).to eq("This notification contains emojis: 🎉🎊🎈")
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
