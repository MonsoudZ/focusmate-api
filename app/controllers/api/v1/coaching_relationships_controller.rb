# frozen_string_literal: true

module Api
  module V1
    class CoachingRelationshipsController < ApplicationController
      before_action :set_relationship, only: %i[
        show
        destroy
        accept
        decline
        update_preferences
      ]

      # GET /api/v1/coaching_relationships
      def index
        relationships =
          if current_user.coach?
            current_user.coaching_relationships_as_coach.includes(:client)
          else
            current_user.coaching_relationships_as_client.includes(:coach)
          end

        relationships = relationships.where(status: params[:status]) if params[:status].present?

        render json: relationships.map { |r| serialize(r) }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:id
      def show
        return render_not_found("Coaching relationship") unless authorized_participant?

        relationship = CoachingRelationship
                         .includes(:coach, :client)
                         .find(@relationship.id)

        render json: serialize(relationship), status: :ok
      end

      # POST /api/v1/coaching_relationships
      def create
        relationship =
          CoachingRelationshipCreationService
            .new(current_user: current_user, params: create_params)
            .create!

        render json: serialize(relationship), status: :created
      rescue CoachingRelationshipCreationService::NotFoundError => e
        render json: { error: { message: e.message } }, status: :not_found
      rescue CoachingRelationshipCreationService::ValidationError => e
        render_unprocessable_content(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        return render_not_found("Coaching relationship") unless @relationship

        relationship =
          CoachingRelationshipAcceptanceService
            .new(relationship: @relationship, current_user: current_user)
            .accept!

        render json: serialize(relationship), status: :ok
      rescue CoachingRelationshipAcceptanceService::UnauthorizedError => e
        render_forbidden(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        return render_not_found("Coaching relationship") unless @relationship

        CoachingRelationshipDeclineService
          .new(relationship: @relationship, current_user: current_user)
          .decline!

        head :no_content
      rescue CoachingRelationshipDeclineService::UnauthorizedError => e
        render_forbidden(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        return render_not_found("Coaching relationship") unless @relationship

        relationship =
          CoachingRelationshipPreferencesService.new(
            relationship: @relationship,
            current_user: current_user,
            params: preferences_params
          ).update!

        render json: {
          id: relationship.id,
          notify_on_completion: relationship.notify_on_completion,
          notify_on_missed_deadline: relationship.notify_on_missed_deadline,
          send_daily_summary: relationship.send_daily_summary,
          daily_summary_time: relationship.daily_summary_time&.strftime("%H:%M")
        }, status: :ok
      rescue CoachingRelationshipPreferencesService::UnauthorizedError => e
        render_forbidden(e.message)
      rescue CoachingRelationshipPreferencesService::ValidationError => e
        render_unprocessable_content(e.message)
      end

      # DELETE /api/v1/coaching_relationships/:id
      def destroy
        return render_not_found("Coaching relationship") unless @relationship
        return render_forbidden("Unauthorized") unless authorized_participant?

        @relationship.destroy!
        head :no_content
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find_by(id: params[:id])
      end

      # ----- Strong params -----
      def create_params
        params.permit(:coach_email, :client_email, :invited_by)
      end

      def preferences_params
        source =
          if params[:coaching_relationship].is_a?(ActionController::Parameters)
            params.require(:coaching_relationship)
          else
            params
          end

        source.permit(
          :notify_on_completion,
          :notify_on_missed_deadline,
          :send_daily_summary,
          :daily_summary_time,
          :timezone
        )
      end

      # ----- Authorization helpers -----
      def authorized_participant?
        @relationship &&
          (@relationship.coach_id == current_user.id ||
            @relationship.client_id == current_user.id)
      end

      # ----- Serialization -----
      def serialize(relationship)
        {
          id: relationship.id,
          coach_id: relationship.coach_id,
          client_id: relationship.client_id,
          status: relationship.status,
          invited_by: relationship.invited_by,
          accepted_at: relationship.accepted_at&.iso8601,
          coach: relationship.association(:coach).loaded? ? {
            id: relationship.coach.id,
            email: relationship.coach.email,
            name: relationship.coach.name
          } : nil,
          client: relationship.association(:client).loaded? ? {
            id: relationship.client.id,
            email: relationship.client.email,
            name: relationship.client.name
          } : nil
        }
      end
    end
  end
end
