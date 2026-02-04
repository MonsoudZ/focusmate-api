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

        invite = @list.invites.build
        assign_invite_attributes(invite)
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
        @list = policy_scope(List).find(params[:list_id])
      end

      def set_invite
        @invite = @list.invites.find(params[:id])
      end

      def assign_invite_attributes(invite)
        attrs = invite_attributes
        invite.role = attrs[:role] if attrs.key?(:role)
        invite.expires_at = attrs[:expires_at] if attrs.key?(:expires_at)
        invite.max_uses = attrs[:max_uses] if attrs.key?(:max_uses)
      end

      def invite_attributes
        payload = invite_payload
        {
          role: payload[:role],
          expires_at: payload[:expires_at],
          max_uses: payload[:max_uses]
        }.compact
      end

      def invite_payload
        raw = params[:invite]
        return {} if raw.blank?

        raise ApplicationError::BadRequest, "invite must be an object" unless raw.is_a?(ActionController::Parameters)

        {
          role: scalar_param(raw[:role]),
          expires_at: scalar_param(raw[:expires_at]),
          max_uses: scalar_param(raw[:max_uses])
        }.compact
      end

      def scalar_param(value)
        return value if value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false

        nil
      end
    end
  end
end
