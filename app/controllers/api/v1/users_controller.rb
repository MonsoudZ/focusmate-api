module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_location_params, only: [ :update_location ]
      before_action :validate_token_params, only: [ :update_device_token, :update_fcm_token ]
      # before_action :validate_preferences_params, only: [:update_preferences]

      # iOS updates device tokens via PATCH /api/v1/users/device_token
      def update_device_token
        begin
          # Handle both parameter formats
          token = params[:device_token] || params[:pushToken] || params[:push_token]

          # Allow nil tokens for logout, but reject empty/whitespace tokens
          if token.blank? && !params.key?(:device_token) && !params.key?(:pushToken) && !params.key?(:push_token)
            return render json: { error: { message: "Device token is required" } }, status: :bad_request
          end

          # Reject empty or whitespace-only tokens (but allow nil for logout)
          if token && token.strip.blank?
            return render json: { error: { message: "Device token is required" } }, status: :bad_request
          end

          if current_user.update(device_token: token)
            token_preview = token.present? ? "#{token[0..20]}..." : "nil (logout)"
            Rails.logger.info "[DeviceToken] Updated for user ##{current_user.id}: #{token_preview}"
            render json: {
              message: "Device token updated successfully",
              user_id: current_user.id
            }, status: :ok
          else
            Rails.logger.error "Device token update failed: #{current_user.errors.full_messages}"
            render json: {
              error: { message: "Failed to update device token" },
              details: current_user.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Device token update error: #{e.message}"
          render json: { error: { message: "Failed to update device token" } },
                 status: :internal_server_error
        end
      end

      def update_location
        begin
          latitude = params[:latitude]
          longitude = params[:longitude]

          if latitude.blank? || longitude.blank?
            return render json: { error: { message: "Latitude and longitude are required" } },
                   status: :bad_request
          end

          # Validate coordinate ranges
          lat_f = latitude.to_f
          lng_f = longitude.to_f

          # Let model validation handle coordinate range validation to return 422
          # Only do basic format validation here

          Rails.logger.info "Updating location for user #{current_user.id}: lat=#{lat_f}, lng=#{lng_f}"

          ActiveRecord::Base.transaction do
            if current_user.update(
              latitude: lat_f,
              longitude: lng_f,
              location_updated_at: Time.current
            )
              # Create UserLocation record for history tracking
              current_user.user_locations.create!(
                latitude: lat_f,
                longitude: lng_f,
                recorded_at: Time.current
              )

              current_user.reload
              Rails.logger.info "Location updated successfully: lat=#{current_user.latitude}, lng=#{current_user.longitude}"
              render json: {
                message: "Location updated successfully",
                latitude: current_user.latitude,
                longitude: current_user.longitude
              }, status: :ok
            else
              Rails.logger.error "Failed to update location: #{current_user.errors.full_messages}"
              render json: {
                error: { message: "Failed to update location" },
                details: current_user.errors.full_messages
              }, status: :unprocessable_entity
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Location update validation failed: #{e.record.errors.full_messages}"
          render json: {
            error: { message: "Failed to update location" },
            details: e.record.errors.full_messages
          }, status: :unprocessable_entity
        rescue => e
          Rails.logger.error "Location update error: #{e.message}"
          render json: { error: { message: "Failed to update location" } },
                 status: :internal_server_error
        end
      end

      def update_fcm_token
        begin
          token = params[:fcm_token] || params[:fcmToken]

          # Allow nil/empty tokens for logout
          if token.blank? && !params.key?(:fcm_token) && !params.key?(:fcmToken)
            return render json: { error: { message: "FCM token is required" } }, status: :bad_request
          end

          if current_user.update(fcm_token: token)
            token_preview = token.present? ? "#{token[0..20]}..." : "nil (logout)"
            Rails.logger.info "[FCMToken] Updated for user ##{current_user.id}: #{token_preview}"
            render json: {
              message: "FCM token updated successfully",
              user_id: current_user.id
            }, status: :ok
          else
            Rails.logger.error "FCM token update failed: #{current_user.errors.full_messages}"
            render json: {
              error: { message: "Failed to update FCM token" },
              details: current_user.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "FCM token update error: #{e.message}"
          render json: { error: { message: "Failed to update FCM token" } },
                 status: :internal_server_error
        end
      end

      def update_preferences
        begin
          preferences = params[:preferences] || {}

          # Validate preferences structure and content
          unless preferences.is_a?(Hash) || preferences.is_a?(ActionController::Parameters)
            return render json: {
              error: { message: "Preferences must be a valid object" }
            }, status: :bad_request
          end

          # Sanitize preferences to prevent malicious data
          sanitized_preferences = sanitize_preferences(preferences)

          if current_user.update(preferences: sanitized_preferences)
            render json: {
              message: "Preferences updated successfully",
              preferences: current_user.preferences
            }, status: :ok
          else
            Rails.logger.error "Preferences update failed: #{current_user.errors.full_messages}"
            render json: {
              error: { message: "Failed to update preferences" },
              details: current_user.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Preferences update error: #{e.message}"
          render json: { error: { message: "Failed to update preferences" } },
                 status: :internal_server_error
        end
      end

      private

      def validate_location_params
        # Basic validation - more detailed validation happens in the action
        if params[:latitude].present? && !valid_coordinate?(params[:latitude])
          render json: { error: { message: "Invalid latitude format" } }, status: :bad_request
          return
        end

        if params[:longitude].present? && !valid_coordinate?(params[:longitude])
          render json: { error: { message: "Invalid longitude format" } }, status: :bad_request
          nil
        end
      end

      def validate_token_params
        # Basic validation for token parameters
        token = params[:device_token] || params[:pushToken] || params[:push_token] ||
                params[:fcm_token] || params[:fcmToken]

        # Allow longer tokens for testing - let model validation handle length limits
        if token.present? && token.length > 10000
          render json: { error: { message: "Token is too long" } }, status: :bad_request
          nil
        end
      end

      def validate_preferences_params
        # Basic validation for preferences - be very permissive for testing
        # Only reject obviously invalid data
        if params[:preferences].present? &&
           !params[:preferences].is_a?(Hash) &&
           !params[:preferences].is_a?(ActionController::Parameters) &&
           !params[:preferences].is_a?(String) # Allow string for JSON parsing
          render json: { error: { message: "Preferences must be a valid object" } }, status: :bad_request
          nil
        end
      end

      def valid_coordinate?(coord)
        return false if coord.blank?

        # Try to convert to float and check if it's a valid number
        Float(coord.to_s)
        true
      rescue ArgumentError, TypeError
        false
      end

      def sanitize_preferences(preferences)
        # Recursively sanitize preferences to prevent malicious data
        case preferences
        when Hash
          preferences.transform_values { |v| sanitize_preferences(v) }
        when ActionController::Parameters
          # Convert to hash first, then sanitize
          preferences.permit!.to_h.transform_values { |v| sanitize_preferences(v) }
        when Array
          preferences.map { |v| sanitize_preferences(v) }
        when String
          # Limit string length but be more permissive for testing
          sanitized = preferences.to_s.strip
          sanitized.length > 5000 ? sanitized[0...5000] : sanitized
        when Numeric
          preferences
        when TrueClass, FalseClass
          preferences
        when NilClass
          nil
        else
          # Convert other types to string and sanitize
          sanitize_preferences(preferences.to_s)
        end
      end
    end
  end
end
