module Api
  module V1
    class DailySummariesController < ApplicationController
      before_action :set_relationship

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries
      def index
        @summaries = @relationship.daily_summaries
                                  .order(summary_date: :desc)
                                  .limit(30) # Last 30 days

        render json: @summaries.map { |s| DailySummarySerializer.new(s).as_json }
      end

      # GET /api/v1/coaching_relationships/:coaching_relationship_id/daily_summaries/:id
      def show
        @summary = @relationship.daily_summaries.find(params[:id])
        render json: DailySummarySerializer.new(@summary, detailed: true).as_json
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find(params[:coaching_relationship_id])

        unless @relationship.coach == current_user || @relationship.client == current_user
          render json: { error: "Unauthorized" }, status: :forbidden
        end
      end
    end
  end
end
