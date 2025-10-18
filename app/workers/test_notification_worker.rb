class TestNotificationWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 0

  def perform(user_id, message = "Test notification")
    user = User.find(user_id)

    Rails.logger.info "[TestNotificationWorker] Sending test notification to user ##{user_id}"

    NotificationService.send_test_notification(user, message)

  rescue => e
    Rails.logger.error "[TestNotificationWorker] Error: #{e.message}"
  end
end
