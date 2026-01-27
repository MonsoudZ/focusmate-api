# frozen_string_literal: true

module Api
  module V1
    class AnalyticsController < BaseController
      skip_after_action :verify_authorized, raise: false
      skip_after_action :verify_policy_scoped, raise: false

      # POST /api/v1/analytics/app_opened
      def app_opened
        AnalyticsTracker.app_opened(
          current_user,
          platform: params[:platform] || "ios",
          version: params[:version]
        )

        head :ok
      end
    end
  end
end
