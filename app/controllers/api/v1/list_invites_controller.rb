# frozen_string_literal: true

module Api
  module V1
    class ListInvitesController < BaseController
      before_action :set_list
      before_action :set_invite, only: %i[show destroy]

      after_action :verify_authorized

      # GET /api/v1/lists/:list_id/invites
      def index
        authorize @list, :manage_memberships?

        invites = @list.invites.order(created_at: :desc)

        render json: {
          invites: invites.map { |i| ListInviteSerializer.new(i).as_json }
        }, status: :ok
      end

      # GET /api/v1/lists/:list_id/invites/:id
      def show
        authorize @list, :manage_memberships?

        render json: {
          invite: ListInviteSerializer.new(@invite).as_json
        }, status: :ok
      end

      # POST /api/v1/lists/:list_id/invites
      def create
        authorize @list, :manage_memberships?

        invite = @list.invites.build(invite_params)
        invite.inviter = current_user

        if invite.save
          render json: {
            invite: ListInviteSerializer.new(invite).as_json
          }, status: :created
        else
          render_validation_error(invite.errors.to_hash)
        end
      end

      # DELETE /api/v1/lists/:list_id/invites/:id
      def destroy
        authorize @list, :manage_memberships?

        @invite.destroy!
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def set_invite
        @invite = @list.invites.find(params[:id])
      end

      def invite_params
        params.fetch(:invite, {}).permit(:role, :expires_at, :max_uses)
      end
    end
  end
end
