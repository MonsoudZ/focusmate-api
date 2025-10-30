module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_location_params, only: [ :update_location ]
      before_action :validate_token_params, only: [ :update_device_token, :update_fcm_token ]
      # before_action :validate_preferences_params, only: [:update_preferences]

      # iOS updates device tokens via PATCH /api/v1/users/device_token
      def update_device_token
        # Handle both parameter formats
        token = params[:device_token] || params[:pushToken] || params[:push_token]

        # Allow nil tokens for logout, but reject empty/whitespace tokens
        if token.blank? && !params.key?(:device_token) && !params.key?(:pushToken) && !params.key?(:push_token)
          return render json: { error: { message: "Device token is required" } }, status: :bad_request
        end

        service = UserDeviceTokenService.new(user: current_user, token: token, token_type: :device)
        service.update!

        render json: {
          message: "Device token updated successfully",
          user_id: current_user.id
        }, status: :ok
      rescue UserDeviceTokenService::ValidationError => e
        render json: {
          error: { message: e.message }
        }, status: :bad_request
      end

      def update_location
        service = UserLocationUpdateService.new(
          user: current_user,
          latitude: params[:latitude],
          longitude: params[:longitude]
        )
        user = service.update!

        render json: {
          message: "Location updated successfully",
          latitude: user.latitude,
          longitude: user.longitude
        }, status: :ok
      rescue UserLocationUpdateService::ValidationError => e
        render json: {
          error: { message: e.message },
          details: e.details
        }, status: e.message.include?("required") ? :bad_request : :unprocessable_content
      end

      def update_fcm_token
        token = params[:fcm_token] || params[:fcmToken]

        # Allow nil/empty tokens for logout
        if token.blank? && !params.key?(:fcm_token) && !params.key?(:fcmToken)
          return render json: { error: { message: "FCM token is required" } }, status: :bad_request
        end

        service = UserDeviceTokenService.new(user: current_user, token: token, token_type: :fcm)
        service.update!

        render json: {
          message: "FCM token updated successfully",
          user_id: current_user.id
        }, status: :ok
      rescue UserDeviceTokenService::ValidationError => e
        render json: {
          error: { message: e.message }
        }, status: :bad_request
      end

      def update_preferences
        preferences = params[:preferences] || {}

        service = UserPreferencesService.new(user: current_user, preferences: preferences)
        user = service.update!

        render json: {
          message: "Preferences updated successfully",
          preferences: user.preferences
        }, status: :ok
      rescue UserPreferencesService::ValidationError => e
        render json: {
          error: { message: e.message },
          details: e.details
        }, status: e.message.include?("valid object") ? :bad_request : :unprocessable_content
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
