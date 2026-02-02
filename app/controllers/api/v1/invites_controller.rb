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
        invite = ListInvite.includes(:list).find_by!(code: params[:code].upcase)

        unless invite.usable?
          message = invite.expired? ? "This invite has expired" : "This invite has reached its usage limit"
          return render_error(message, status: :gone, code: "invite_unusable")
        end

        if invite.list.user_id == current_user.id
          return render_error("You are the owner of this list", status: :unprocessable_entity, code: "already_owner")
        end

        if invite.list.memberships.exists?(user_id: current_user.id)
          return render_error("You are already a member of this list", status: :conflict, code: "already_member")
        end

        ActiveRecord::Base.transaction do
          invite.list.memberships.create!(user: current_user, role: invite.role)
          invite.increment_uses!

          # Create mutual friendship if not already friends
          unless Friendship.friends?(invite.inviter, current_user)
            Friendship.create_mutual!(invite.inviter, current_user)
          end
        end

        AnalyticsTracker.list_shared(invite.list, invite.inviter, shared_with: current_user, role: invite.role)

        render json: {
          message: "Successfully joined list",
          list: ListSerializer.new(invite.list, current_user: current_user).as_json
        }, status: :ok
      end
    end
  end
end
