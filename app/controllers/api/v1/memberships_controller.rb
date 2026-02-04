# frozen_string_literal: true

module Api
  module V1
    class MembershipsController < BaseController
      before_action :set_list
      before_action :set_membership, only: %i[update destroy]

      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      # GET /api/v1/lists/:list_id/memberships
      # Returns list owner and all members
      def index
        authorize @list, :show?

        memberships = policy_scope(@list.memberships)
                        .includes(:user)
                        .order(created_at: :asc)
                        .limit(100)

        owner = @list.user

        render json: {
          owner: {
            id: owner.id,
            email: owner.email,
            name: owner.name
          },
          memberships: memberships.map { |m| MembershipSerializer.new(m).as_json }
        }, status: :ok
      end

      # POST /api/v1/lists/:list_id/memberships
      def create
        authorize @list, :manage_memberships?

        membership = Memberships::Create.call!(
          list: @list,
          inviter: current_user,
          user_identifier: create_params[:user_identifier],
          friend_id: create_params[:friend_id],
          role: create_params[:role]
        )

        AnalyticsTracker.list_shared(@list, current_user, shared_with: membership.user, role: membership.role)

        render json: { membership: MembershipSerializer.new(membership).as_json }, status: :created
      end

      # PATCH /api/v1/lists/:list_id/memberships/:id
      def update
        authorize @list, :manage_memberships?

        membership = Memberships::Update.call!(
          membership: @membership,
          role: update_params[:role]
        )

        render json: { membership: MembershipSerializer.new(membership).as_json }, status: :ok
      end

      # DELETE /api/v1/lists/:list_id/memberships/:id
      def destroy
        authorize @list, :manage_memberships?

        Memberships::Destroy.call!(membership: @membership, actor: current_user)

        head :no_content
      end

      private

      def set_list
        @list = policy_scope(List).find(params[:list_id])
      end

      def set_membership
        @membership = @list.memberships.find(params[:id])
      end

      def create_params
        payload = membership_payload
        {
          user_identifier: payload[:user_identifier],
          friend_id: payload[:friend_id],
          role: payload[:role]
        }
      end

      def update_params
        payload = membership_payload
        {
          role: payload[:role]
        }
      end

      def membership_payload
        raw = params.require(:membership)
        raise ApplicationError::BadRequest, "membership must be an object" unless raw.is_a?(ActionController::Parameters)

        raw
      end
    end
  end
end
