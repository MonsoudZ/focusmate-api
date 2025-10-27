# frozen_string_literal: true

module Api
  module V1
    class DashboardController < ApplicationController
      # GET /api/v1/dashboard
      def show
        render json: DashboardDataService.new(user: current_user).call
      end

      # GET /api/v1/dashboard/stats
      def stats
        render json: DashboardDataService.new(user: current_user).stats
      end
    end
  end
end
