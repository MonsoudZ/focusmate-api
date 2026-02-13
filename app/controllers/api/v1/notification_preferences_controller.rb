# frozen_string_literal: true

module Api
  module V1
    class NotificationPreferencesController < BaseController
      # GET /api/v1/notification_preference
      def show
        preference = find_or_create_preference
        authorize preference

        render json: { notification_preference: NotificationPreferenceSerializer.one(preference) }, status: :ok
      end

      # PATCH /api/v1/notification_preference
      def update
        preference = find_or_create_preference
        authorize preference

        preference.update!(preference_params)

        render json: { notification_preference: NotificationPreferenceSerializer.one(preference) }, status: :ok
      end

      private

      def find_or_create_preference
        current_user.notification_preference || current_user.create_notification_preference!
      end

      def preference_params
        params.permit(:nudge_enabled, :task_assigned_enabled, :list_joined_enabled, :task_reminder_enabled)
      end
    end
  end
end
