# app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      # iOS can call this as PUT /devices/token or PATCH /users/device_token
      def update_device_token
        # Handle both parameter formats
        token = params[:device_token] || params[:pushToken] || params[:push_token]

        # Allow nil tokens for logout, but reject empty/whitespace tokens
        if token.blank? && !params.key?(:device_token) && !params.key?(:pushToken) && !params.key?(:push_token)
          render json: { error: "Device token is required" }, status: :bad_request
          return
        end
        
        # Reject empty or whitespace-only tokens (but allow nil for logout)
        if token && token.strip.blank?
          render json: { error: "Device token is required" }, status: :bad_request
          return
        end

        if current_user.update(device_token: token)
          token_preview = token.present? ? "#{token[0..20]}..." : "nil (logout)"
          Rails.logger.info "[DeviceToken] Updated for user ##{current_user.id}: #{token_preview}"
          render json: {
            message: "Device token updated successfully",
            user_id: current_user.id
          }, status: :ok
        else
          render json: {
            error: "Failed to update device token",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update_location
        latitude = params[:latitude]
        longitude = params[:longitude]

        if latitude.blank? || longitude.blank?
          render json: { error: "Latitude and longitude are required" }, status: :bad_request
          return
        end

        Rails.logger.info "Updating location for user #{current_user.id}: lat=#{latitude}, lng=#{longitude}"
        
        if current_user.update(
          latitude: latitude.to_f,
          longitude: longitude.to_f,
          location_updated_at: Time.current
        )
          # Create UserLocation record for history tracking
          current_user.user_locations.create!(
            latitude: latitude.to_f,
            longitude: longitude.to_f,
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
            error: "Failed to update location",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update_fcm_token
        token = params[:fcm_token] || params[:fcmToken]

        # Allow nil/empty tokens for logout
        if token.blank? && !params.key?(:fcm_token) && !params.key?(:fcmToken)
          render json: { error: "FCM token is required" }, status: :bad_request
          return
        end

        if current_user.update(fcm_token: token)
          token_preview = token.present? ? "#{token[0..20]}..." : "nil (logout)"
          Rails.logger.info "[FCMToken] Updated for user ##{current_user.id}: #{token_preview}"
          render json: {
            message: "FCM token updated successfully",
            user_id: current_user.id
          }, status: :ok
        else
          render json: {
            error: "Failed to update FCM token",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update_preferences
        preferences = params[:preferences] || {}

        if current_user.update(preferences: preferences)
          render json: {
            message: "Preferences updated successfully",
            preferences: current_user.preferences
          }, status: :ok
        else
          render json: {
            error: "Failed to update preferences",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
end
