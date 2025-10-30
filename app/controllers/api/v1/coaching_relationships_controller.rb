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
        attrs = create_params
        coach_email  = normalize_email(attrs[:coach_email])
        client_email = normalize_email(attrs[:client_email])
        invited_by   = attrs[:invited_by].presence

        if coach_email.blank? && client_email.blank?
          return render_unprocessable_content("Must provide coach_email or client_email")
        end

        # Decide inviter/invitee
        if invited_by == "coach" || (invited_by.blank? && client_email.present?)
          coach  = current_user
          client = find_user_ci(client_email || coach_email)
          unless client
            return render json: { error: { message: "Client not found with that email" } }, status: :not_found
          end
          return render_unprocessable_content("You cannot invite yourself") if client.id == coach.id
          invited_by = "coach"
        else
          client = current_user
          coach  = find_user_ci(coach_email || client_email)
          unless coach
            return render json: { error: { message: "Coach not found with that email" } }, status: :not_found
          end
          return render_unprocessable_content("You cannot invite yourself") if coach.id == client.id
          invited_by = "client"
        end

        # Check for existing relationship
        existing = CoachingRelationship.where(coach_id: coach.id, client_id: client.id).first
        if existing
          return render_unprocessable_content("Relationship already exists")
        end

        rel = CoachingRelationship.new(coach:, client:, invited_by:, status: "pending")
        rel.save!

        # Reload with associations
        rel = CoachingRelationship.includes(:coach, :client).find(rel.id)

        # Call NotificationService if it exists
        begin
          NotificationService.coaching_invitation_sent(rel) if defined?(NotificationService) && NotificationService.respond_to?(:coaching_invitation_sent)
        rescue => e
          Rails.logger.error "[CoachingRelationshipsController] Error sending invitation notification: #{e.message}"
        end

        render json: serialize(rel), status: :created
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        return render_not_found("Coaching relationship") unless @relationship
        return render_forbidden("You cannot accept this invitation") unless invitee?(@relationship, current_user) && @relationship.status.to_s == "pending"

        @relationship.update!(status: "active", accepted_at: Time.current)

        # Reload with associations
        @relationship = CoachingRelationship.includes(:coach, :client).find(@relationship.id)

        # Call NotificationService if it exists
        begin
          NotificationService.coaching_invitation_accepted(@relationship) if defined?(NotificationService) && NotificationService.respond_to?(:coaching_invitation_accepted)
        rescue => e
          Rails.logger.error "[CoachingRelationshipsController] Error sending acceptance notification: #{e.message}"
        end

        render json: serialize(@relationship), status: :ok
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        return render_not_found("Coaching relationship") unless @relationship
        return render_forbidden("You cannot decline this invitation") unless invitee?(@relationship, current_user) && @relationship.status.to_s == "pending"

        @relationship.update!(status: "declined")

        # Call NotificationService if it exists
        begin
          NotificationService.coaching_invitation_declined(@relationship) if defined?(NotificationService) && NotificationService.respond_to?(:coaching_invitation_declined)
        rescue => e
          Rails.logger.error "[CoachingRelationshipsController] Error sending decline notification: #{e.message}"
        end

        head :no_content
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        return render_not_found("Coaching relationship") unless @relationship
        return render_forbidden("Only coaches can update preferences") unless current_user.id == @relationship.coach_id

        changes = prefs_params.to_h.symbolize_keys

        # Remove timezone - it's accepted but not stored (for future use)
        changes.delete(:timezone)

        # Convert HH:MM string to Time object if provided
        if changes.key?(:daily_summary_time)
          val = changes[:daily_summary_time]
          if val.blank?
            changes[:daily_summary_time] = nil
          elsif val.is_a?(String)
            # Validate HH:MM format
            if val.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/)
              # Parse as time today (Rails will store just the time part)
              changes[:daily_summary_time] = Time.zone.parse(val)
            elsif val.present?
              return render_unprocessable_content("Validation failed")
            end
          end
        end

        # Convert string booleans to actual booleans
        [:notify_on_completion, :notify_on_missed_deadline, :send_daily_summary].each do |key|
          if changes.key?(key)
            val = changes[key]
            # Handle string boolean values
            if val.is_a?(String)
              val_lower = val.downcase.strip
              changes[key] = !["false", "0", "no", "off", "f", "n", ""].include?(val_lower)
            else
              changes[key] = ActiveModel::Type::Boolean.new.cast(val)
            end
          end
        end

        begin
          @relationship.update!(changes)
        rescue ActiveRecord::RecordInvalid => e
          return render_unprocessable_content("Validation failed")
        end

        render json: {
          id: @relationship.id,
          notify_on_completion:      @relationship.notify_on_completion,
          notify_on_missed_deadline: @relationship.notify_on_missed_deadline,
          send_daily_summary:        @relationship.send_daily_summary,
          daily_summary_time:        @relationship.daily_summary_time&.strftime("%H:%M")
        }, status: :ok
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
