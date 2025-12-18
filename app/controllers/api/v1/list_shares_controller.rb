# frozen_string_literal: true

module Api
  module V1
    class ListSharesController < ApplicationController
      include Paginatable

      before_action :authenticate_user!, except: :accept_invitation
      before_action :set_list, except: :accept_invitation
      before_action :set_share, only: %i[show update destroy update_permissions accept decline]

      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      def index
        authorize @list, :manage_shares?

        shares = policy_scope(
          ListShares::Query.call!(
            list: @list,
            params: params
          )
        )

        result = paginate_if_requested(shares)

        render json: ListShareSerializer.collection(result[:records], result[:pagination]),
               status: :ok
      end

      def show
        authorize @share
        render json: ListShareSerializer.one(@share), status: :ok
      end

      def create
        authorize @list, :manage_shares?

        result = ListShares::Create.call!(
          list: @list,
          inviter: current_user,
          params: create_params
        )

        render json: ListShareSerializer.one(result[:share]),
               status: result[:created] ? :created : :ok
      end

      def update
        authorize @share

        @share.update!(update_params)
        render json: ListShareSerializer.one(@share), status: :ok
      end

      def update_permissions
        authorize @share

        share = ListShares::UpdatePermissions.call!(
          share: @share,
          params: permission_params
        )

        render json: ListShareSerializer.one(share), status: :ok
      end

      def destroy
        authorize @share
        @share.destroy!
        head :no_content
      end

      def accept
        authorize @share

        share = ListShares::Accept.call!(
          share: @share,
          actor: current_user,
          token: params[:invitation_token]
        )

        render json: ListShareSerializer.one(share), status: :ok
      end

      def decline
        authorize @share
        ListShares::Decline.call!(share: @share, actor: current_user)
        head :no_content
      end

      def accept_invitation
        ListShares::Accept.accept_by_token!(token: params[:token])
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def set_share
        @share = @list.list_shares.find(params[:id])
      end

      def create_params
        params.permit(:email, :role, :can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end

      def update_params
        params.permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end

      def permission_params
        params.require(:permissions).permit(
          :can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications
        )
      end

      def paginate_if_requested(scope)
        return { records: scope } unless params[:page].present? || params[:per_page].present?

        result = apply_pagination(scope, default_per_page: 25, max_per_page: 50)
        { records: result[:paginated_query], pagination: result[:pagination_metadata] }
      end
    end
  end
end
