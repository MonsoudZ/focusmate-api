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
      metadata: notification.metadata || {},
      read: notification.read?,
      created_at: notification.created_at.iso8601,
      updated_at: notification.updated_at.iso8601
    }
  end
end
