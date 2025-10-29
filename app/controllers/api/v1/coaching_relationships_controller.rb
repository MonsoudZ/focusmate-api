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

        render json: rels.map { |r| serialize(r) }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:id
      def show
        return not_found! unless @relationship
        return forbidden! unless participant?(@relationship, current_user)
        render json: serialize(@relationship), status: :ok
      end

      # POST /api/v1/coaching_relationships
      def create
        attrs = create_params
        coach_email  = normalize_email(attrs[:coach_email])
        client_email = normalize_email(attrs[:client_email])
        invited_by   = attrs[:invited_by].presence

        if coach_email.blank? && client_email.blank?
          return validation_error!(daily_error("base", "Must provide coach_email or client_email"))
        end

        # Decide inviter/invitee
        if invited_by == "coach" || (invited_by.blank? && client_email.present?)
          coach  = current_user
          client = find_user_ci(client_email || coach_email) or return not_found!("Client not found with that email")
          return validation_error!(daily_error("base", "You cannot invite yourself")) if client.id == coach.id
          invited_by = "coach"
        else
          client = current_user
          coach  = find_user_ci(coach_email || client_email) or return not_found!("Coach not found with that email")
          return validation_error!(daily_error("base", "You cannot invite yourself")) if coach.id == client.id
          invited_by = "client"
        end

        rel = CoachingRelationship.new(coach:, client:, invited_by:, status: "pending")

        begin
          rel.save!
        rescue ActiveRecord::RecordNotUnique
          return validation_error!(daily_error("base", "Relationship already exists"))
        end

        notify_async(:coaching_invitation_sent, rel)
        render json: serialize(rel), status: :created
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        return not_found! unless @relationship
        return forbidden!("You cannot accept this invitation") unless invitee?(@relationship, current_user)
        return forbidden!("You cannot accept this invitation") unless @relationship.status.to_s == "pending"

        @relationship.update!(status: "active", accepted_at: Time.current)
        notify_async(:coaching_invitation_accepted, @relationship)
        render json: serialize(@relationship), status: :ok
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        return not_found! unless @relationship
        return forbidden!("You cannot decline this invitation") unless invitee?(@relationship, current_user)
        return forbidden!("You cannot decline this invitation") unless @relationship.status.to_s == "pending"

        @relationship.update!(status: "declined")
        notify_async(:coaching_invitation_declined, @relationship)
        head :no_content
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        return not_found! unless @relationship
        return forbidden!("Only coaches can update preferences") unless current_user.id == @relationship.coach_id

        changes = prefs_params.to_h.symbolize_keys

        # Convert HH:MM → minutesSinceMidnight (int) if provided
        if changes.key?(:daily_summary_time)
          val = changes.delete(:daily_summary_time)
          minutes = parse_hhmm_minutes(val)
          return validation_error!(daily_error("daily_summary_time", "must be in HH:MM format")) if val.present? && minutes.nil?
          changes[:daily_summary_minutes] = minutes
        end

        upsert_preferences(@relationship, changes)
        @relationship.save!

        render json: {
          id: @relationship.id,
          notify_on_completion:      current_pref(@relationship, :notify_on_completion),
          notify_on_missed_deadline: current_pref(@relationship, :notify_on_missed_deadline),
          send_daily_summary:        current_pref(@relationship, :send_daily_summary),
          daily_summary_time:        minutes_to_hhmm(current_pref(@relationship, :daily_summary_minutes))
        }, status: :ok
      end

      # DELETE /api/v1/coaching_relationships/:id
      def destroy
        return not_found! unless @relationship
        return forbidden! unless participant?(@relationship, current_user)
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
        src.permit(:notify_on_completion, :notify_on_missed_deadline, :send_daily_summary, :daily_summary_time)
      end

      # ----- AuthZ helpers (replace with Pundit ASAP) -----
      def participant?(rel, user) = rel.coach_id == user.id || rel.client_id == user.id
      def invitee?(rel, user)     = rel.invited_by == "coach" ? (rel.client_id == user.id) : (rel.coach_id == user.id)

      # ----- Error helpers (uniform) -----
      def not_found!(msg = "Coaching relationship not found")
        render json: { code: "not_found", message: msg }, status: :not_found
      end

      def forbidden!(msg = "Forbidden")
        render json: { code: "forbidden", message: msg }, status: :forbidden
      end

      def validation_error!(details_hash)
        render json: { code: "validation_error", message: "Validation failed", details: details_hash.as_json }, status: :unprocessable_entity
      end

      def daily_error(field, msg)
        { field => [ msg ] }
      end

      # ----- Prefs storage helpers -----
      def upsert_preferences(rel, changes)
        if rel.respond_to?(:preferences) && rel.preferences.is_a?(Hash)
          rel.preferences = (rel.preferences || {}).merge(changes.stringify_keys)
        else
          changes.each do |k, v|
            setter = "#{k}="
            rel.public_send(setter, v) if rel.respond_to?(setter)
          end
        end
      end

      def current_pref(rel, key)
        if rel.respond_to?(key)
          rel.public_send(key)
        elsif rel.respond_to?(:preferences) && rel.preferences.is_a?(Hash)
          rel.preferences[key.to_s]
        end
      end

      # ----- Utilities -----
      def normalize_email(email)
        email.to_s.strip.downcase.presence
      end

      def find_user_ci(email)
        e = email.to_s.strip
        return nil if e.blank?
        User.where("LOWER(email) = ?", e.downcase).first
      end

      # "HH:MM" -> integer minutes or nil
      def parse_hhmm_minutes(val)
        s = val.to_s.strip
        return nil if s.blank?
        return nil unless s =~ /\A([01]?\d|2[0-3]):[0-5]\d\z/
        hh, mm = s.split(":").map!(&:to_i)
        (hh * 60) + mm
      end

      def minutes_to_hhmm(val)
        return nil unless val.present?
        hh = val.to_i / 60
        mm = val.to_i % 60
        format("%02d:%02d", hh, mm)
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

      def notify_async(method, rel)
        return unless defined?(NotificationService) && NotificationService.respond_to?(method)
        NotificationJob.perform_later(method.to_s, rel.id)
      end
    end
  end
end
