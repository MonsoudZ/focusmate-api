module Api
  module V1
    class ListSharesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_list, only: %i[index create show update destroy update_permissions accept decline]
      before_action :set_list_share, only: %i[show update destroy update_permissions accept decline]
      before_action :authorize_list_owner, only: %i[index create update update_permissions]
      before_action :authorize_share_owner_or_list_owner, only: %i[destroy]
      before_action :authorize_share_access, only: %i[show]

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
        # ---- Spec: empty body / missing email -> 400 Bad Request with { error: { message: "Email is required" } }
        if params.blank? || params[:email].to_s.strip.blank?
          return render json: { error: { message: "Email is required" } }, status: :bad_request
        end

        email = params[:email].to_s.downcase.strip
        role  = params[:role].presence || "viewer"

        # If already shared, return the existing share (spec expects OK rather than error)
        if (existing_share = @list.list_shares.find_by(email: email))
          return render json: ListShareSerializer.new(existing_share).as_json, status: :ok
        end

        invited_user = User.find_by(email: email)

        begin
          @list_share =
            if invited_user
              # existing user -> create accepted/pending based on your model logic
              @list.share_with!(invited_user, share_params.merge(role: role))
            else
              # non-existent user -> pending invite
              @list.invite_by_email!(email, role, share_params)
            end

          if @list_share.persisted?
            render json: ListShareSerializer.new(@list_share).as_json, status: :created
          else
            render json: { error: { message: "Validation failed", details: @list_share.errors.as_json } },
                   status: :unprocessable_content
          end
        rescue => e
          Rails.logger.error "Create share failed: #{e.class}: #{e.message}"
          render json: { error: { message: "Validation failed" } }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id
      def update
        if @list_share.update(share_params)
          render json: ListShareSerializer.new(@list_share).as_json
        else
          render json: { error: { message: "Validation failed", details: @list_share.errors.as_json } },
                 status: :unprocessable_content
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id/update_permissions
      def update_permissions
        if @list_share.update_permissions(permission_params)
          render json: ListShareSerializer.new(@list_share).as_json
        else
          render json: { error: { message: "Validation failed", details: @list_share.errors.as_json } },
                 status: :unprocessable_content
        end
      end

      # DELETE /api/v1/lists/:list_id/shares/:id
      def destroy
        @list_share.destroy
        head :no_content
      end

      # POST /api/v1/lists/:list_id/shares/:id/accept
      def accept
        # If a token is provided but doesn't match, spec expects this exact error:
        if params.key?(:invitation_token)
          given = params[:invitation_token].to_s
          expected = @list_share.invitation_token.to_s
          if given.blank? || given != expected
            return render json: { error: { message: "Invitation is not pending" } }, status: :unprocessable_content
          end
        end

        # If the share has no token or is not pending, return error
        if @list_share.invitation_token.blank? || !@list_share.pending?
          return render json: { error: { message: "Invitation is not pending" } }, status: :unprocessable_content
        end

        @list_share.accept!(current_user)
        @list_share.reload
        render json: ListShareSerializer.new(@list_share).as_json, status: :ok
      end

      # POST /api/v1/lists/:list_id/shares/:id/decline
      def decline
        unless @list_share.pending?
          return render json: { error: { message: "Invitation is not pending" } }, status: :unprocessable_content
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
        end
      end

      def authorize_share_access
        return if @list.viewable_by?(current_user) || @list_share.user == current_user
        render json: { error: { message: "Unauthorized" } }, status: :forbidden
      end

      def authorize_share_owner_or_list_owner
        return if @list.owner == current_user || @list_share.user == current_user

        # Default: assume they're trying to delete a share they don't own
        render json: { error: { message: "Only list owner or share owner can delete this share" } }, status: :forbidden
      end

      def share_params
        params.permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
      end

      def permission_params
        permitted = params.require(:permissions).permit(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications)
        permitted.to_h.transform_values do |v|
          case v
          when true, false then v
          when nil, ""     then false
          else
            v.to_s.strip.downcase.in?(%w[true yes on 1])
          end
        end
      end
    end
  end
end
