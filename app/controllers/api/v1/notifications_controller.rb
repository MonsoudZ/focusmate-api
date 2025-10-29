module Api
  module V1
    class NotificationsController < ApplicationController
      before_action :validate_page_params, only: [ :index ]
      # GET /api/v1/notifications
      def index
        begin
          logs = build_notifications_query

          # Apply pagination at database level
          page = [ params[:page].to_i, 1 ].max
          per_page = per_page_limit
          offset = (page - 1) * per_page

          paginated_logs = logs.limit(per_page).offset(offset)

          render json: paginated_logs.map { |notification|
            NotificationSerializer.new(notification).as_json
          }
        rescue => e
          Rails.logger.error "NotificationsController#index error: #{e.message}"
          render json: { error: { message: "Failed to retrieve notifications" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/notifications/:id/mark_read
      def mark_read
        begin
          notification = current_user.notification_logs.find(params[:id])
          notification.mark_read!
          head :no_content
        rescue ActiveRecord::RecordNotFound
          render json: { error: { message: "Resource not found" } }, status: :not_found
        rescue => e
          Rails.logger.error "NotificationsController#mark_read error: #{e.message}"
          render json: { error: { message: "Failed to mark notification as read" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/notifications/mark_all_read
      def mark_all_read
        begin
          # Use bulk update for better performance
          NotificationLog.for_user(current_user)
                        .where("metadata->>'read' IS NULL OR metadata->>'read' != 'true'")
                        .update_all("metadata = jsonb_set(metadata, '{read}', 'true')")

          head :no_content
        rescue => e
          Rails.logger.error "NotificationsController#mark_all_read error: #{e.message}"
          render json: { error: { message: "Failed to mark all notifications as read" } },
                 status: :internal_server_error
        end
      end

      private

      def build_notifications_query
        logs = NotificationLog.for_user(current_user).recent

        # Apply read filter at database level using scopes
        if params.key?(:read)
          read_value = parse_read_filter(params[:read])
          case read_value
          when true
            logs = logs.read
          when false
            logs = logs.unread
          end
        end

        logs
      end

      def parse_read_filter(value)
        case value.to_s.downcase
        when "true", "1", "t", "yes", "y", "read"   then true
        when "false", "0", "f", "no", "n", "unread" then false
        else nil
        end
      end

      def per_page_limit
        per = params[:per_page].to_i
        per = 10 if per <= 0
        per = 50 if per > 50

        # If there are many notifications and no per_page specified, use 50
        if params[:per_page].blank? && NotificationLog.for_user(current_user).count > 20
          per = 50
        end

        per
      end

      def validate_page_params
        # Validate page parameter
        if params[:page].present? && params[:page].to_i < 1
          render json: { error: { message: "Page parameter must be a positive integer" } },
                 status: :bad_request
          return
        end

        # Validate per_page parameter
        if params[:per_page].present? && (params[:per_page].to_i < 1 || params[:per_page].to_i > 50)
          render json: { error: { message: "Per page parameter must be between 1 and 50" } },
                 status: :bad_request
          return
        end

        # Validate read parameter
        if params[:read].present?
          valid_read_values = %w[true false 1 0 t f yes no y n read unread]
          unless valid_read_values.include?(params[:read].to_s.downcase)
            render json: { error: { message: "Invalid read parameter value" } },
                   status: :bad_request
            nil
          end
        end
      end
    end
  end
end
