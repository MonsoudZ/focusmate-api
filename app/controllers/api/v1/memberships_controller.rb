# frozen_string_literal: true

module Api
  module V1
    class MembershipsController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate_user!
      before_action :set_list
      before_action :set_membership, only: %i[show update destroy]

      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize @list, :show?

        memberships = policy_scope(@list.memberships)
                        .includes(:user)
                        .order(created_at: :asc)

        render json: MembershipSerializer.collection(memberships), status: :ok
      end

      def show
        authorize @list, :show?
        render json: MembershipSerializer.one(@membership), status: :ok
      end

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

      def update
        authorize @list, :manage_memberships?

        membership = Memberships::Update.call!(
          membership: @membership,
          actor: current_user,
          role: update_params[:role]
        )

        render json: MembershipSerializer.one(membership), status: :ok
      end

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
        @membership = @list.memberships.includes(:user).find(params[:id])
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
