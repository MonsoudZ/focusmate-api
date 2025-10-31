# frozen_string_literal: true

class NotificationBulkUpdateService
  class ValidationError < StandardError; end

  def initialize(user:)
    @user = user
  end

  def mark_all_read!
    # Use bulk update for better performance
    affected_count = NotificationLog.for_user(@user)
                                    .where("metadata->>'read' IS NULL OR metadata->>'read' != 'true'")
                                    .update_all("metadata = jsonb_set(metadata, '{read}', 'true')")

    Rails.logger.info "[NotificationBulkUpdateService] Marked #{affected_count} notifications as read for user ##{@user.id}"

    affected_count
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error "[NotificationBulkUpdateService] Database error: #{e.message}"
    raise ValidationError, "Failed to mark all notifications as read"
  rescue StandardError => e
    Rails.logger.error "[NotificationBulkUpdateService] Error: #{e.message}"
    raise ValidationError, "Failed to mark all notifications as read"
  end
end
