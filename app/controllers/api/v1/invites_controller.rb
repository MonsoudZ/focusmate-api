# frozen_string_literal: true

module Api
  module V1
    class InvitesController < BaseController
      skip_before_action :authenticate_user!, only: [ :show ]

      # GET /api/v1/invites/:code
      # Public endpoint to preview an invite before accepting
      def show
        invite = find_active_invite!

        render json: {
          invite: ListInviteSerializer.new(invite).as_preview_json
        }, status: :ok
      end

      # POST /api/v1/invites/:code/accept
      def accept
        invite = find_active_invite!
        list = invite.list

        validate_invite_acceptance!(invite, list)

        ActiveRecord::Base.transaction do
          atomically_increment_uses!(invite)
          create_membership!(list, invite.role)
          Friendship.ensure_mutual!(invite.inviter, current_user)
        end

        AnalyticsTracker.list_shared(list, invite.inviter, shared_with: current_user, role: invite.role)
        PushNotifications::Sender.send_list_joined(to_user: list.user, new_member: current_user, list: list)

        render json: {
          message: "Successfully joined list",
          list: ListSerializer.new(list, current_user: current_user).as_json
        }, status: :ok
      end

      private

      def validate_invite_acceptance!(invite, list)
        unless invite.usable?
          raise ApplicationError::Gone.new(invite_unusable_message(invite), code: "invite_unusable")
        end

        if list.user_id == current_user.id
          raise ApplicationError::UnprocessableEntity.new("You are the owner of this list", code: "already_owner")
        end

        if list.memberships.exists?(user_id: current_user.id)
          raise ApplicationError::Conflict.new("You are already a member of this list", code: "already_member")
        end
      end

      # Atomic increment that only succeeds if invite is still usable.
      # Prevents race conditions without explicit locking.
      def atomically_increment_uses!(invite)
        rows_updated = ListInvite
          .where(id: invite.id)
          .where("max_uses IS NULL OR uses_count < max_uses")
          .where("expires_at IS NULL OR expires_at > ?", Time.current)
          .update_all("uses_count = uses_count + 1")

        if rows_updated == 0
          invite.reload
          raise ApplicationError::Gone.new(invite_unusable_message(invite), code: "invite_unusable")
        end
      end

      def create_membership!(list, role)
        list.memberships.create!(user: current_user, role: role)
      rescue ActiveRecord::RecordNotUnique
        raise ApplicationError::Conflict.new("You are already a member of this list", code: "already_member")
      rescue ActiveRecord::RecordInvalid => e
        raise ApplicationError::Conflict.new("You are already a member of this list", code: "already_member") if e.record.errors.added?(:user_id, :taken)
        raise
      end

      def invite_unusable_message(invite)
        invite.expired? ? "This invite has expired" : "This invite has reached its usage limit"
      end

      def find_active_invite!
        ListInvite
          .includes(:list, :inviter)
          .joins(:list)
          .merge(List.not_deleted)
          .find_by!(code: normalized_invite_code)
      end

      def normalized_invite_code
        params[:code].to_s.strip.upcase
      end
    end
  end
end
