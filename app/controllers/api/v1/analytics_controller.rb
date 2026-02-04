# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      VALID_PLATFORMS = %w[ios android web].freeze
      MAX_VERSION_LENGTH = 64

      skip_after_action :verify_authorized, raise: false
      skip_after_action :verify_policy_scoped, raise: false

      # POST /api/v1/analytics/app_opened
      def app_opened
        payload = analytics_payload

        AnalyticsTracker.app_opened(
          current_user,
          platform: payload[:platform],
          version: payload[:version]
        )

        head :ok
      end

      private

      def analytics_payload
        analytics = analytics_params
        raw_platform = scalar_param(analytics[:platform]).to_s.strip.downcase
        raw_version = scalar_param(analytics[:version]).to_s.strip

        {
          platform: normalize_platform(raw_platform),
          version: normalize_version(raw_version)
        }
      end

      def analytics_params
        params.permit(:platform, :version)
      end

      def scalar_param(value)
        return value if value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false

        nil
      end

      def normalize_platform(value)
        return "ios" if value.blank?
        return value if VALID_PLATFORMS.include?(value)

        "ios"
      end

      def normalize_version(value)
        return nil if value.blank?

        value[0...MAX_VERSION_LENGTH]
      end
    end
  end
end
