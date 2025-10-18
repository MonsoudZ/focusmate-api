module Api
  module V1
    class NotificationsController < ApplicationController
      # GET /api/v1/notifications
      def index
        @notifications = current_user.notification_logs
                                     .order(created_at: :desc)
                                     .limit(50)

        render json: @notifications.map { |n| NotificationSerializer.new(n).as_json }
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        notification = current_user.notification_logs.find(params[:id])
        notification.update!(metadata: notification.metadata.merge(read: true))

        head :no_content
      end

      # PATCH /api/v1/notifications/mark_all_read
      def mark_all_read
        current_user.notification_logs.update_all(
          metadata: { read: true }
        )

        head :no_content
      end
    end
  end
end
