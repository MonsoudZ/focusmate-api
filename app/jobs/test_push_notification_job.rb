class TestPushNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id:, title: "Test Push", body: "This is a test push notification", data: {})
    user = User.find(user_id)

    Rails.logger.info "[TestPushNotificationJob] Sending test push to user #{user.id} (#{user.email})"

    # Check if user has devices
    if user.devices.empty?
      Rails.logger.warn "[TestPushNotificationJob] User #{user.id} has no registered devices"
      return
    end

    # Send test notification to all devices
    begin
      NotificationService.send_test_notification(
        user,
        "#{title}: #{body}"
      )
      Rails.logger.info "[TestPushNotificationJob] Test notification sent to user #{user.id}"
    rescue => e
      Rails.logger.error "[TestPushNotificationJob] Failed to send test notification to user #{user.id}: #{e.message}"
      raise e
    end

    Rails.logger.info "[TestPushNotificationJob] Test push notification completed for user #{user.id}"
  end
end
