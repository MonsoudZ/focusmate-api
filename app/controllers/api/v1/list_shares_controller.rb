module Api
  module V1
    class ListSharesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_list, only: [ :index, :create, :show, :update, :destroy, :update_permissions, :accept, :decline ]
      before_action :set_list_share, only: [ :show, :update, :destroy, :update_permissions, :accept, :decline ]
      before_action :authorize_list_owner, only: [ :index, :create, :update, :update_permissions ]
      before_action :authorize_share_owner_or_list_owner, only: [ :destroy ]
      before_action :authorize_share_access, only: [ :show ]

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
        role = params[:role] || "viewer"

        if email.blank?
          render json: { errors: { email: ["is required"] } }, status: :unprocessable_entity
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

        begin
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
              error: "Failed to create share",
              details: @list_share.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error "Create share failed: #{e.message}"
          render json: {
            error: { message: "Validation failed" }
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
          render json: { error: { message: "Invitation is not pending" } }, status: :unprocessable_entity
          return
        end

        @list_share.accept!(current_user)
        @list_share.reload
        render json: ListShareSerializer.new(@list_share).as_json
      end

      # POST /api/v1/lists/:list_id/shares/:id/decline
      def decline
        unless @list_share.pending?
          render json: { error: { message: "Invitation is not pending" } }, status: :unprocessable_entity
          return
        end

        @list_share.decline!
        render json: { message: "Invitation declined" }
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
          render json: { error: { message: "Only list owner can manage shares" } }, status: :forbidden
          return
        end
      end

      def authorize_share_access
        unless @list.viewable_by?(current_user) || @list_share.user == current_user
          render json: { error: { message: "Unauthorized" } }, status: :forbidden
          return
        end
      end

      def authorize_share_owner_or_list_owner
        unless @list.owner == current_user || @list_share.user == current_user
          render json: { error: { message: "Only list owner or share owner can delete this share" } }, status: :forbidden
          return
        end
      end

      def share_params
        params.permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end

      def permission_params
        permitted = params.require(:permissions).permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
        # Convert string boolean values to actual booleans and handle nil/empty values
        permitted.each do |key, value|
          if value.nil? || (value.is_a?(String) && value.empty?)
            permitted[key] = false
          elsif value.is_a?(String)
            case value.downcase
            when 'true', 'yes', 'on', '1'
              permitted[key] = true
            when 'false', 'no', 'off', '0'
              permitted[key] = false
            end
          end
        end
        permitted
      end
    end
  end
end
