class NotificationSerializer
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def as_json
    {
      id: notification.id,
      type: notification.notification_type,
      title: notification.title,
      message: notification.message,
      read: notification.metadata&.dig('read') || false,
      priority: notification.priority,
      created_at: notification.created_at.iso8601,
      metadata: notification.metadata || {}
    }
  end
end