module Api
  module V1
    class NotificationsController < ApplicationController
      # GET /api/v1/notifications
      def index
        logs = NotificationLog.for_user(current_user).recent

        # read filter supports true/false/1/0/t/f/yes/no/read/unread
        if params.key?(:read)
          want =
            case params[:read].to_s.downcase
            when "true", "1", "t", "yes", "y", "read"   then true
            when "false", "0", "f", "no", "n", "unread" then false
            else
              nil
            end
          logs = logs.select { |n| n.read? == want } unless want.nil?
        end

        # paginate with a hard cap of 50 (spec expects cap = 50)
        page = params[:page].to_i
        page = 1 if page <= 0
        per  = params[:per_page].to_i
        per  = 10 if per <= 0
        per  = 50 if per > 50

        # If there are many notifications and no per_page specified, use 50
        if params[:per_page].blank? && logs.count > 20
          per = 50
        end

        start = (page - 1) * per
        paged = logs.to_a.slice(start, per) || []

        render json: paged.map { |n|
          {
            id: n.id,
            notification_type: n.notification_type,
            message: n.message,
            delivered: n.delivered,
            delivered_at: n.delivered_at,
            metadata: n.metadata,
            read: n.read?,
            created_at: n.created_at,
            updated_at: n.updated_at
          }
        }
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        notification = current_user.notification_logs.find(params[:id])
        notification.mark_read!

        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: { message: "Resource not found" } }, status: :not_found
      end

      # PATCH /api/v1/notifications/mark_all_read
      def mark_all_read
        NotificationLog.for_user(current_user).find_each do |n|
          m = n.metadata.dup
          m["read"] = true
          n.update!(metadata: m)
        end
        head :no_content
      end
    end
  end
end
