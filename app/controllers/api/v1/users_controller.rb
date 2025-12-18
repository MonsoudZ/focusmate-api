# frozen_string_literal: true

module Api
  module V1
    class UsersController < BaseController
      # BaseController should already authenticate; keep this only if it doesn't.
      # before_action :authenticate_user!

      # PATCH /api/v1/users/location
      def update_location
        user = UserLocationUpdateService.new(
          user: current_user,
          latitude: params[:latitude],
          longitude: params[:longitude]
        ).update!

        render json: {
          message: "Location updated successfully",
          latitude: user.latitude,
          longitude: user.longitude
        }, status: :ok
      rescue UserLocationUpdateService::ValidationError => e
        render json: {
          error: { message: e.message },
          details: e.details
        }, status: :unprocessable_content
      end

      # PATCH /api/v1/users/preferences
      def update_preferences
        user = UserPreferencesService.new(
          user: current_user,
          preferences: preferences_param
        ).update!

        render json: {
          message: "Preferences updated successfully",
          preferences: user.preferences
        }, status: :ok
      rescue UserPreferencesService::ValidationError => e
        render json: {
          error: { message: e.message },
          details: e.details
        }, status: :unprocessable_content
      end

      private

      # Accept either:
      # - { preferences: {...} }
      # - { preferences: "<json string>" } (some clients do this)
      def preferences_param
        raw = params[:preferences]

        return {} if raw.nil?
        return raw.permit!.to_h if raw.is_a?(ActionController::Parameters)
        return raw if raw.is_a?(Hash)

        if raw.is_a?(String)
          JSON.parse(raw)
        else
          raw
        end
      rescue JSON::ParserError
        raise UserPreferencesService::ValidationError.new(
          "Preferences must be valid JSON",
          { preferences: [ "invalid_json" ] }
        )
      end
    end
  end
end
