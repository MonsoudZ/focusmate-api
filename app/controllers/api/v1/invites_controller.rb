# frozen_string_literal: true

module Api
  module V1
    class InvitesController < BaseController
      skip_before_action :authenticate_user!, only: [ :show ]

      # GET /api/v1/invites/:code
      # Public endpoint to preview an invite before accepting
      def show
        invite = ListInvite.includes(:list, :inviter).find_by!(code: params[:code].upcase)

        render json: {
          invite: ListInviteSerializer.new(invite).as_preview_json
        }, status: :ok
      end

      # POST /api/v1/invites/:code/accept
      def accept
        invite = ListInvite.includes(:list, :inviter).find_by!(code: params[:code].upcase)

        # Quick pre-checks for better error messages
        unless invite.usable?
          message = invite.expired? ? "This invite has expired" : "This invite has reached its usage limit"
          return render_error(message, status: :gone, code: "invite_unusable")
        end

        if invite.list.user_id == current_user.id
          return render_error("You are the owner of this list", status: :unprocessable_content, code: "already_owner")
        end

        if invite.list.memberships.exists?(user_id: current_user.id)
          return render_error("You are already a member of this list", status: :conflict, code: "already_member")
        end

        ActiveRecord::Base.transaction do
          # Atomic increment that only succeeds if invite is still usable
          # This prevents race conditions without explicit locking
          rows_updated = ListInvite
            .where(id: invite.id)
            .where("max_uses IS NULL OR uses_count < max_uses")
            .where("expires_at IS NULL OR expires_at > ?", Time.current)
            .update_all("uses_count = uses_count + 1")

          if rows_updated == 0
            invite.reload
            raise ApplicationError::Gone.new(
              invite.expired? ? "This invite has expired" : "This invite has reached its usage limit",
              code: "invite_unusable"
            )
          end

          begin
            invite.list.memberships.create!(user: current_user, role: invite.role)
          rescue ActiveRecord::RecordNotUnique
            raise ApplicationError::Conflict.new("You are already a member of this list", code: "already_member")
          rescue ActiveRecord::RecordInvalid => e
            if e.record.errors.added?(:user_id, :taken)
              raise ApplicationError::Conflict.new("You are already a member of this list", code: "already_member")
            end
            raise
          end

          # Ensure mutual friendship between inviter and invitee.
          # This is idempotent and race-safe under concurrent accept flows.
          Friendship.ensure_mutual!(invite.inviter, current_user)
        end

        AnalyticsTracker.list_shared(invite.list, invite.inviter, shared_with: current_user, role: invite.role)

        # Notify list owner that someone joined
        PushNotifications::Sender.send_list_joined(
          to_user: invite.list.user,
          new_member: current_user,
          list: invite.list
        )

        render json: {
          message: "Successfully joined list",
          list: ListSerializer.new(invite.list, current_user: current_user).as_json
        }, status: :ok
      end
    end
  end
end
