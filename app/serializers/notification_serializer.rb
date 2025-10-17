class NotificationSerializer
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def as_json
    {
      id: notification.id,
      notification_type: notification.notification_type,
      message: notification.message,
      delivered: notification.delivered,
      delivered_at: notification.delivered_at&.iso8601,
      read: notification.metadata&.dig('read') || false,
      task_id: notification.task_id,
      created_at: notification.created_at.iso8601
    }
  end
end
