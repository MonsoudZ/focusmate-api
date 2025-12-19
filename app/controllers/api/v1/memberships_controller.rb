# frozen_string_literal: true

module Api
  module V1
    class MembershipsController < BaseController
      before_action :set_list
      before_action :set_membership, only: %i[update destroy]

      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      # GET /api/v1/lists/:list_id/memberships
      def index
        authorize @list, :show?

        memberships = policy_scope(@list.memberships)
                        .includes(:user)
                        .order(created_at: :asc)

        render json: MembershipSerializer.collection(memberships), status: :ok
      end

      # POST /api/v1/lists/:list_id/memberships
      def create
        authorize @list, :manage_memberships?

        membership = Memberships::Create.call!(
          list: @list,
          inviter: current_user,
          user_identifier: create_params[:user_identifier],
          role: create_params[:role]
        )

        render json: MembershipSerializer.one(membership), status: :created
      end

      # PATCH /api/v1/lists/:list_id/memberships/:id
      def update
        authorize @list, :manage_memberships?

        membership = Memberships::Update.call!(
          membership: @membership,
          actor: current_user,
          role: update_params[:role]
        )

        render json: MembershipSerializer.one(membership), status: :ok
      end

      # DELETE /api/v1/lists/:list_id/memberships/:id
      def destroy
        authorize @list, :manage_memberships?

        Memberships::Destroy.call!(membership: @membership, actor: current_user)

        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def set_membership
        @membership = @list.memberships.find(params[:id])
      end

      def create_params
        params.require(:membership).permit(:user_identifier, :role)
      end

      def update_params
        params.require(:membership).permit(:role)
      end
    end
  end
end
