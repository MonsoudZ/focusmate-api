# frozen_string_literal: true

# frozen_string_literal: true

module Api
  module V1
    class CoachingRelationshipsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_relationship, only: %i[show accept decline update_preferences destroy]

      def index
        relationships = CoachingRelationships::Query.call!(
          user: current_user,
          status: params[:status]
        )

        render json: CoachingRelationshipSerializer.collection(relationships), status: :ok
      end

      def show
        authorize @relationship
        render json: CoachingRelationshipSerializer.one(@relationship), status: :ok
      end

      def create
        relationship = CoachingRelationships::Create.call!(
          current_user: current_user,
          params: create_params
        )

        render json: CoachingRelationshipSerializer.one(relationship), status: :created
      end

      def accept
        authorize @relationship

        relationship = CoachingRelationships::Accept.call!(
          relationship: @relationship,
          actor: current_user
        )

        render json: CoachingRelationshipSerializer.one(relationship), status: :ok
      end

      def decline
        authorize @relationship

        CoachingRelationships::Decline.call!(
          relationship: @relationship,
          actor: current_user
        )

        head :no_content
      end

      def update_preferences
        authorize @relationship

        relationship = CoachingRelationships::UpdatePreferences.call!(
          relationship: @relationship,
          actor: current_user,
          params: preferences_params
        )

        render json: CoachingRelationshipSerializer.preferences(relationship), status: :ok
      end

      def destroy
        authorize @relationship
        @relationship.destroy!
        head :no_content
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find(params[:id])
      end

      def create_params
        params.permit(:coach_email, :client_email, :invited_by)
      end

      def preferences_params
        source =
          params[:coaching_relationship].is_a?(ActionController::Parameters) ?
            params.require(:coaching_relationship) :
            params

        source.permit(
          :notify_on_completion,
          :notify_on_missed_deadline,
          :send_daily_summary,
          :daily_summary_time,
          :timezone
        )
      end
    end
  end
end
