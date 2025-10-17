module Api
  module V1
    class ListSharesController < ApplicationController
      before_action :authenticate_user!, except: [:accept]
      before_action :set_list, only: [:index, :create, :accept, :decline]
      before_action :set_list_share, only: [:show, :update, :destroy, :update_permissions, :accept, :decline]
      before_action :authorize_list_owner, only: [:create, :update, :destroy, :update_permissions]
      before_action :authorize_share_access, only: [:show]

      # GET /api/v1/lists/:list_id/shares
      def index
        @shares = @list.list_shares.includes(:user)
        render json: @shares.map { |share| ListShareSerializer.new(share).as_json }
      end

      # GET /api/v1/lists/:list_id/shares/:id
      def show
        render json: ListShareSerializer.new(@list_share).as_json
      end

      # POST /api/v1/lists/:list_id/shares
      def create
        email = params[:email]&.downcase&.strip
        role = params[:role] || 'viewer'
        
        if email.blank?
          render json: { error: 'Email is required' }, status: :bad_request
          return
        end
        
        # Check if already shared
        existing_share = @list.list_shares.find_by(email: email)
        if existing_share
          # Instead of error, return the existing share with 200 OK
          render json: ListShareSerializer.new(existing_share).as_json, status: :ok
          return
        end
        
        # Find user by email (or create pending share)
        invited_user = User.find_by(email: email)
        
        if invited_user
          # User exists, create accepted share
          @list_share = @list.share_with!(invited_user, share_params.merge(role: role))
        else
          # User doesn't exist, create pending invitation
          @list_share = @list.invite_by_email!(email, role, share_params)
        end
        
        if @list_share.persisted?
          render json: ListShareSerializer.new(@list_share).as_json, status: :created
        else
          render json: { 
            error: 'Failed to create share',
            details: @list_share.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id
      def update
        if @list_share.update(share_params)
          render json: ListShareSerializer.new(@list_share).as_json
        else
          render json: { errors: @list_share.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id/update_permissions
      def update_permissions
        if @list_share.update_permissions(permission_params)
          render json: ListShareSerializer.new(@list_share).as_json
        else
          render json: { errors: @list_share.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/lists/:list_id/shares/:id
      def destroy
        @list_share.destroy
        head :no_content
      end

      # POST /api/v1/lists/:list_id/shares/:id/accept
      def accept
        unless @list_share.pending?
          render json: { error: 'Invitation is not pending' }, status: :unprocessable_entity
          return
        end

        @list_share.accept!(current_user)
        render json: ListShareSerializer.new(@list_share).as_json
      end

      # POST /api/v1/lists/:list_id/shares/:id/decline
      def decline
        unless @list_share.pending?
          render json: { error: 'Invitation is not pending' }, status: :unprocessable_entity
          return
        end

        @list_share.decline!
        render json: { message: 'Invitation declined' }
      end

      # POST /api/v1/list_shares/accept (for email links)
      def accept
        token = params.require(:token)
        share = ListShare.find_by!(invitation_token: token, status: "pending")
        
        if current_user.blank?
          # If user is not authenticated, find by email
          user = User.find_by!(email: share.email)
        else
          user = current_user
        end

        share.update!(
          user: user,
          status: "accepted", 
          accepted_at: Time.current, 
          invitation_token: nil
        )
        
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def set_list_share
        @list_share = @list.list_shares.find(params[:id])
      end

      def authorize_list_owner
        unless @list.owner == current_user
          render json: { error: 'Only list owner can manage shares' }, status: :forbidden
        end
      end

      def authorize_share_access
        unless @list.viewable_by?(current_user) || @list_share.user == current_user
          render json: { error: 'Unauthorized' }, status: :forbidden
        end
      end

      def share_params
        params.permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end

      def permission_params
        params.require(:permissions).permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end
    end
  end
end