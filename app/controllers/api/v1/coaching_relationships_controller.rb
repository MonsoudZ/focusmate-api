# app/controllers/api/v1/coaching_relationships_controller.rb
module Api
  module V1
    class CoachingRelationshipsController < ApplicationController
      before_action :require_auth!
      before_action :set_relationship, only: [ :show, :destroy, :accept, :decline, :update_preferences ]

      # GET /api/v1/coaching_relationships
      def index
        rels =
          if current_user.coach?
            current_user.coaching_relationships_as_coach.includes(:client)
          else
            current_user.coaching_relationships_as_client.includes(:coach)
          end

        render json: rels.map { |rel| CoachingRelationshipSerializer.new(rel, current_user: current_user).as_json }, status: :ok
      end

      # GET /api/v1/coaching_relationships/:id
      def show
        return not_found! unless @relationship && participant?(@relationship, current_user)
        render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json, status: :ok
      end

      # POST /api/v1/coaching_relationships
      def create
        coach_email  = normalize_email(params[:coach_email])
        client_email = normalize_email(params[:client_email])
        invited_by   = params[:invited_by].presence

        if coach_email.blank? && client_email.blank?
          return render json: { error: { message: "Must provide coach_email or client_email" } }, status: :unprocessable_entity
        end

        if invited_by == "coach" || (invited_by.blank? && client_email.present?)
          # coach invites client
          coach  = current_user
          client = find_user_ci(client_email || coach_email)
          return not_found!("Client not found with that email") unless client
          return render json: { error: { message: "You cannot invite yourself" } }, status: :unprocessable_entity if client.id == coach.id
          invited_by = "coach"
        else
          # client invites coach
          client = current_user
          coach  = find_user_ci(coach_email || client_email)
          return not_found!("Coach not found with that email") unless coach
          return render json: { error: { message: "You cannot invite yourself" } }, status: :unprocessable_entity if coach.id == client.id
          invited_by = "client"
        end

        if CoachingRelationship.exists?(coach_id: coach.id, client_id: client.id)
          return render json: { error: { message: "Relationship already exists" } }, status: :unprocessable_entity
        end

        rel = CoachingRelationship.new(
          coach: coach,
          client: client,
          invited_by: invited_by,
          status: "pending"
        )

        if rel.save
          safe_notify(:coaching_invitation_sent, rel)
          render json: CoachingRelationshipSerializer.new(rel, current_user: current_user).as_json, status: :created
        else
          validation_error!(rel.errors)
        end
      end

      # PATCH /api/v1/coaching_relationships/:id/accept
      def accept
        return not_found! unless @relationship && participant?(@relationship, current_user)
        return forbidden!("You cannot accept this invitation") unless invitee?(@relationship, current_user)
        return forbidden!("You cannot accept this invitation") unless @relationship.status.to_s == "pending"

        @relationship.update!(status: "active", accepted_at: Time.current)
        safe_notify(:coaching_invitation_accepted, @relationship)
        render json: CoachingRelationshipSerializer.new(@relationship, current_user: current_user).as_json, status: :ok
      end

      # PATCH /api/v1/coaching_relationships/:id/decline
      def decline
        return not_found! unless @relationship && participant?(@relationship, current_user)
        return forbidden!("You cannot decline this invitation") unless invitee?(@relationship, current_user)
        return forbidden!("You cannot decline this invitation") unless @relationship.status.to_s == "pending"

        @relationship.update!(status: "declined")
        safe_notify(:coaching_invitation_declined, @relationship)
        head :no_content
      end

      # PATCH /api/v1/coaching_relationships/:id/update_preferences
      def update_preferences
        return not_found! unless @relationship && participant?(@relationship, current_user)
        return forbidden!("Only coaches can update preferences") unless current_user.id == @relationship.coach_id

        src = params[:coaching_relationship].is_a?(ActionController::Parameters) ? params[:coaching_relationship] : params

        changes = {}
        changes[:notify_on_completion]      = to_bool(src[:notify_on_completion])      if src.key?(:notify_on_completion)
        changes[:notify_on_missed_deadline] = to_bool(src[:notify_on_missed_deadline]) if src.key?(:notify_on_missed_deadline)
        changes[:send_daily_summary]        = to_bool(src[:send_daily_summary])        if src.key?(:send_daily_summary)

        if src.key?(:daily_summary_time)
          if src[:daily_summary_time].present?
            hhmm = parse_hhmm(src[:daily_summary_time])
            return render json: { error: { message: "Validation failed", details: { daily_summary_time: [ "must be in HH:MM format" ] } } }, status: :unprocessable_entity unless hhmm
            changes[:daily_summary_time] = hhmm
          else
            # allow clearing with empty string / nil
            changes[:daily_summary_time] = nil
          end
        end

        # Persist either in serialized preferences hash or direct attributes
        if @relationship.respond_to?(:preferences) && @relationship.preferences.is_a?(Hash)
          @relationship.preferences = (@relationship.preferences || {}).merge(changes.stringify_keys)
        else
          changes.each do |k, v|
            setter = "#{k}="
            if @relationship.respond_to?(setter)
              if k == :daily_summary_time && v.present?
                # Convert string time to Time object for database storage
                time_parts = v.split(":")
                time_obj = Time.zone.parse("#{time_parts[0]}:#{time_parts[1]}")
                @relationship.public_send(setter, time_obj)
              else
                @relationship.public_send(setter, v)
              end
            end
          end
        end

        @relationship.save!

        render json: {
          id: @relationship.id,
          notify_on_completion:      current_pref(:notify_on_completion),
          notify_on_missed_deadline: current_pref(:notify_on_missed_deadline),
          send_daily_summary:        current_pref(:send_daily_summary),
          daily_summary_time:        format_hhmm(current_pref(:daily_summary_time))
        }, status: :ok
      end

      # DELETE /api/v1/coaching_relationships/:id
      def destroy
        return not_found! unless @relationship
        return forbidden!("Unauthorized") unless participant?(@relationship, current_user)
        @relationship.destroy!
        head :no_content
      end

      private

      def require_auth!
        return if current_user.present?
        render json: { error: { message: "Unauthorized" } }, status: :unauthorized
      end

      def set_relationship
        @relationship = CoachingRelationship.find_by(id: params[:id])
      end

      def participant?(rel, user)
        rel.coach_id == user.id || rel.client_id == user.id
      end

      def invitee?(rel, user)
        rel.invited_by == "coach" ? (rel.client_id == user.id) : (rel.coach_id == user.id)
      end

      # ---------- response helpers ----------

      def not_found!(msg = "Coaching relationship not found")
        render json: { error: { message: msg } }, status: :not_found
      end

      def forbidden!(msg)
        render json: { error: { message: msg } }, status: :forbidden
      end

      def validation_error!(details_hash)
        render json: { error: { message: "Validation failed", details: details_hash.as_json } }, status: :unprocessable_entity
      end

      # ---------- lookups / coercion / formatting ----------

      def normalize_email(email)
        email.to_s.strip.downcase.presence
      end

      def find_user_ci(email)
        e = email.to_s.strip
        return nil if e.blank?
        User.where("LOWER(email) = ?", e.downcase).first
      end

      def to_bool(val)
        return val if val == true || val == false
        s = val.to_s.strip.downcase
        return true  if %w[true 1 yes y t on].include?(s)
        return false if %w[false 0 no n f off].include?(s)
        nil
      end

      # returns "HH:MM" or nil for invalid
      def parse_hhmm(val)
        s = val.to_s.strip
        return nil unless s =~ /\A([01]?\d|2[0-3]):[0-5]\d\z/
        hh, mm = s.split(":")
        format("%02d:%02d", hh.to_i, mm.to_i)
      end

      # normalize stored value into "HH:MM" or nil
      def format_hhmm(val)
        return nil if val.blank?
        return val if val.is_a?(String) && val.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/)
        if val.respond_to?(:strftime)
          return val.strftime("%H:%M")
        end
        s = val.to_s
        return s if s.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/)
        nil
      end

      def current_pref(key)
        if @relationship.respond_to?(key)
          @relationship.public_send(key)
        elsif @relationship.respond_to?(:preferences) && @relationship.preferences.is_a?(Hash)
          @relationship.preferences[key.to_s]
        end
      end

      def safe_notify(method, rel)
        return unless defined?(NotificationService)
        return unless NotificationService.respond_to?(method)
        NotificationService.public_send(method, rel)
      rescue StandardError
        # swallow notifications during tests
      end
    end
  end
end
