# app/controllers/api/v1/coaching_relationships_controller.rb
module Api
  module V1
    class CoachingRelationshipsController < ApplicationController
      before_action :set_relationship, only: %i[show destroy accept decline update_preferences]

      # GET /api/v1/coaching_relationships
      def index
        rels =
          if current_user.coach?
            current_user.coaching_relationships_as_coach.includes(:client)
          else
            current_user.coaching_relationships_as_client.includes(:coach)
          end

        # Filter by status if provided
        if params[:status].present?
          rels = rels.where(status: params[:status])
        end

        render json: rels.map { |r| serialize(r) }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:id
      def show
        # Return 404 if relationship doesn't exist OR user is not a participant
        return render_not_found("Coaching relationship") unless @relationship && participant?(@relationship, current_user)
        # Ensure associations are loaded
        @relationship = CoachingRelationship.includes(:coach, :client).find(@relationship.id)
        render json: serialize(@relationship), status: :ok
      end

      # POST /api/v1/coaching_relationships
      def create
        service = CoachingRelationshipCreationService.new(current_user: current_user, params: create_params)
        rel = service.create!
        render json: serialize(rel), status: :created
      rescue CoachingRelationshipCreationService::NotFoundError => e
        render json: { error: { message: e.message } }, status: :not_found
      rescue CoachingRelationshipCreationService::ValidationError => e
        render_unprocessable_content(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        return render_not_found("Coaching relationship") unless @relationship

        service = CoachingRelationshipAcceptanceService.new(relationship: @relationship, current_user: current_user)
        relationship = service.accept!
        render json: serialize(relationship), status: :ok
      rescue CoachingRelationshipAcceptanceService::UnauthorizedError => e
        render_forbidden(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        return render_not_found("Coaching relationship") unless @relationship

        service = CoachingRelationshipDeclineService.new(relationship: @relationship, current_user: current_user)
        service.decline!
        head :no_content
      rescue CoachingRelationshipDeclineService::UnauthorizedError => e
        render_forbidden(e.message)
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        return render_not_found("Coaching relationship") unless @relationship

        service = CoachingRelationshipPreferencesService.new(
          relationship: @relationship,
          current_user: current_user,
          params: prefs_params
        )
        relationship = service.update!

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
        return render_forbidden("Unauthorized") unless participant?(@relationship, current_user)
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

      def prefs_params
        # Accept both root and nested payloads
        src = params[:coaching_relationship].is_a?(ActionController::Parameters) ? params.require(:coaching_relationship) : params
        src.permit(:notify_on_completion, :notify_on_missed_deadline, :send_daily_summary, :daily_summary_time, :timezone)
      end

      # ----- AuthZ helpers (replace with Pundit ASAP) -----
      def participant?(rel, user) = rel.coach_id == user.id || rel.client_id == user.id
      def invitee?(rel, user)     = rel.invited_by == "coach" ? (rel.client_id == user.id) : (rel.coach_id == user.id)

      # ----- Utilities -----
      def normalize_email(email)
        email.to_s.strip.downcase.presence
      end

      def find_user_ci(email)
        e = email.to_s.strip
        return nil if e.blank?
        User.where("LOWER(email) = ?", e.downcase).first
      end

      def serialize(rel)
        # If you have a serializer, prefer that; otherwise inline:
        {
          id: rel.id,
          coach_id: rel.coach_id,
          client_id: rel.client_id,
          status: rel.status,
          invited_by: rel.invited_by,
          accepted_at: rel.accepted_at&.iso8601,
          coach: rel.association(:coach).loaded? ? { id: rel.coach.id, email: rel.coach.email, name: rel.coach.name } : nil,
          client: rel.association(:client).loaded? ? { id: rel.client.id, email: rel.client.email, name: rel.client.name } : nil
        }
      end
    end
  end
end
