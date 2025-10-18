# app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!

      # iOS can call this as PUT /devices/token or PATCH /users/device_token
      def update_device_token
        # Handle both parameter formats
        token = params[:device_token] || params[:pushToken] || params[:push_token]

        if token.blank?
          render json: { error: "Device token is required" }, status: :bad_request
          return
        end

        if current_user.update(device_token: token)
          Rails.logger.info "[DeviceToken] Updated for user ##{current_user.id}: #{token[0..20]}..."
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

        if current_user.update(
          latitude: latitude.to_f,
          longitude: longitude.to_f,
          location_updated_at: Time.current
        )
          render json: {
            message: "Location updated successfully",
            latitude: current_user.latitude,
            longitude: current_user.longitude
          }, status: :ok
        else
          render json: {
            error: "Failed to update location",
            details: current_user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def update_fcm_token
        token = params[:fcm_token] || params[:fcmToken]

        if token.blank?
          render json: { error: "FCM token is required" }, status: :bad_request
          return
        end

        if current_user.update(fcm_token: token)
          Rails.logger.info "[FCMToken] Updated for user ##{current_user.id}: #{token[0..20]}..."
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
