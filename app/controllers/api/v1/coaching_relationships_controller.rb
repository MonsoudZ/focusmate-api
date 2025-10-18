module Api
  module V1
    class CoachingRelationshipsController < ApplicationController
      before_action :set_relationship, only: [ :show, :destroy, :accept, :decline, :update_preferences ]

      # GET /api/v1/coaching_relationships
      def index
        if current_user.coach?
          @relationships = current_user.coaching_relationships_as_coach.includes(:client)
        else
          @relationships = current_user.coaching_relationships_as_client.includes(:coach)
        end

        render json: @relationships.map { |rel| CoachingRelationshipSerializer.new(rel, current_user: current_user).as_json }
      end

      # GET /api/v1/coaching_relationships/:id
      def show
        render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json
      end

      # POST /api/v1/coaching_relationships
      def create
        # Determine role based on params
        if params[:coach_email].present?
          # Client is inviting a coach
          coach = User.find_by(email: params[:coach_email], role: "coach")

          unless coach
            return render json: { error: "Coach not found with that email" }, status: :not_found
          end

          @relationship = CoachingRelationship.new(
            coach: coach,
            client: current_user,
            invited_by: "client",
            status: "pending"
          )
        elsif params[:client_email].present?
          # Coach is inviting a client
          client = User.find_by(email: params[:client_email], role: "client")

          unless client
            return render json: { error: "Client not found with that email" }, status: :not_found
          end

          @relationship = CoachingRelationship.new(
            coach: current_user,
            client: client,
            invited_by: "coach",
            status: "pending"
          )
        else
          return render json: { error: "Must provide coach_email or client_email" }, status: :unprocessable_entity
        end

        if @relationship.save
          # Send notification to invitee
          NotificationService.coaching_invitation_sent(@relationship)

          render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json, status: :created
        else
          render json: { errors: @relationship.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        unless can_respond_to_invitation?
          return render json: { error: "You cannot accept this invitation" }, status: :forbidden
        end

        @relationship.accept!
        NotificationService.coaching_invitation_accepted(@relationship)

        render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        unless can_respond_to_invitation?
          return render json: { error: "You cannot decline this invitation" }, status: :forbidden
        end

        @relationship.decline!
        NotificationService.coaching_invitation_declined(@relationship)

        head :no_content
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        unless @relationship.coach == current_user
          return render json: { error: "Only coaches can update preferences" }, status: :forbidden
        end

        if @relationship.update(preference_params)
          render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json
        else
          render json: { errors: @relationship.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/coaching_relationships/:id
      def destroy
        unless @relationship.coach == current_user || @relationship.client == current_user
          return render json: { error: "Unauthorized" }, status: :forbidden
        end

        @relationship.destroy
        head :no_content
      end

      private

      def set_relationship
        @relationship = CoachingRelationship.find(params[:id])
      end

      def can_respond_to_invitation?
        return false unless @relationship.status == "pending"

        if @relationship.invited_by == "coach"
          @relationship.client == current_user
        else
          @relationship.coach == current_user
        end
      end

      def preference_params
        params.require(:coaching_relationship).permit(
          :notify_on_completion,
          :notify_on_missed_deadline,
          :send_daily_summary,
          :daily_summary_time
        )
      end
    end
  end
end
