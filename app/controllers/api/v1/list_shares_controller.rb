module Api
  module V1
    class ListSharesController < ApplicationController
      include Paginatable

      before_action :authenticate_user!, except: [ :accept_invitation ]
      before_action :set_list, only: %i[index create show update destroy update_permissions accept decline]
      before_action :set_list_share, only: %i[show update destroy update_permissions accept decline]
      before_action :authorize_list_user, only: %i[index create update update_permissions]
      before_action :authorize_share_user_or_list_user, only: %i[destroy]
      before_action :authorize_share_access, only: %i[show]
      before_action :validate_share_params, only: %i[create update update_permissions]
      before_action -> { validate_pagination_params(valid_order_fields: %w[created_at email role status invited_at]) }, only: [ :index ]

      # GET /api/v1/lists/:list_id/shares
      def index
        begin
          shares = build_shares_query

          # Check if pagination is requested
          if params[:page].present? || params[:per_page].present?
            result = apply_pagination(shares, default_per_page: 25, max_per_page: 50)

            render json: {
              shares: result[:paginated_query].map { |share| ListShareSerializer.new(share).as_json },
              pagination: result[:pagination_metadata]
            }
          else
            # Return simple array for backward compatibility
            render json: shares.map { |share| ListShareSerializer.new(share).as_json }
          end
        rescue => e
          Rails.logger.error "ListSharesController#index error: #{e.message}"
          render json: { error: { message: "Failed to retrieve shares" } },
                 status: :internal_server_error
        end
      end

      # GET /api/v1/lists/:list_id/shares/:id
      def show
        begin
          render json: ListShareSerializer.new(@list_share).as_json
        rescue => e
          Rails.logger.error "ListSharesController#show error: #{e.message}"
          render json: { error: { message: "Failed to retrieve share" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/lists/:list_id/shares
      def create
        begin
          service = ListShareCreationService.new(list: @list, current_user: current_user)
          result = service.create!(
            email: params[:email],
            role: params[:role],
            permissions: share_params
          )

          status = result[:created] ? :created : :ok
          render json: ListShareSerializer.new(result[:share]).as_json, status: status
        rescue ListShareCreationService::BadRequestError => e
          render json: { error: { message: e.message } }, status: :bad_request
        rescue ListShareCreationService::ValidationError => e
          render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
        rescue => e
          Rails.logger.error "Create share failed: #{e.class}: #{e.message}"
          render json: { error: { message: "Failed to create share" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id
      def update
        begin
          if @list_share.update(share_params)
            render json: ListShareSerializer.new(@list_share).as_json
          else
            Rails.logger.error "Share update validation failed: #{@list_share.errors.full_messages}"
            render json: { error: { message: "Validation failed", details: @list_share.errors.as_json } },
                   status: :unprocessable_content
          end
        rescue => e
          Rails.logger.error "Share update failed: #{e.message}"
          render json: { error: { message: "Failed to update share" } },
                 status: :internal_server_error
        end
      end

      # PATCH /api/v1/lists/:list_id/shares/:id/update_permissions
      def update_permissions
        begin
          if @list_share.update_permissions(permission_params)
            render json: ListShareSerializer.new(@list_share).as_json
          else
            Rails.logger.error "Permission update validation failed: #{@list_share.errors.full_messages}"
            render json: { error: { message: "Validation failed", details: @list_share.errors.as_json } },
                   status: :unprocessable_content
          end
        rescue => e
          Rails.logger.error "Permission update failed: #{e.message}"
          render json: { error: { message: "Failed to update permissions" } },
                 status: :internal_server_error
        end
      end

      # DELETE /api/v1/lists/:list_id/shares/:id
      def destroy
        begin
          @list_share.destroy
          head :no_content
        rescue => e
          Rails.logger.error "Share deletion failed: #{e.message}"
          render json: { error: { message: "Failed to delete share" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/lists/:list_id/shares/:id/accept
      def accept
        begin
          service = ListShareAcceptanceService.new(list_share: @list_share, current_user: current_user)
          list_share = service.accept!(invitation_token: params[:invitation_token])
          render json: ListShareSerializer.new(list_share).as_json, status: :ok
        rescue ListShareAcceptanceService::ValidationError => e
          render json: { error: { message: e.message } }, status: :unprocessable_content
        rescue => e
          Rails.logger.error "Share acceptance failed: #{e.message}"
          render json: { error: { message: "Failed to accept invitation" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/lists/:list_id/shares/:id/decline
      def decline
        begin
          service = ListShareDeclineService.new(list_share: @list_share)
          service.decline!
          render json: { message: "Invitation declined" }
        rescue ListShareDeclineService::ValidationError => e
          render json: { error: { message: e.message } }, status: :unprocessable_content
        rescue => e
          Rails.logger.error "Share decline failed: #{e.message}"
          render json: { error: { message: "Failed to decline invitation" } },
                 status: :internal_server_error
        end
      end

      # POST /api/v1/list_shares/accept
      # Public endpoint for accepting invitations via email link (no authentication required)
      def accept_invitation
        begin
          ListShareAcceptanceService.accept_by_token!(token: params[:token])
          head :no_content
        rescue ListShareAcceptanceService::ValidationError => e
          render json: { error: { message: e.message } }, status: :bad_request
        rescue ListShareAcceptanceService::NotFoundError => e
          render json: { error: { message: e.message } }, status: :not_found
        rescue => e
          Rails.logger.error "Accept invitation failed: #{e.message}"
          render json: { error: { message: "Failed to accept invitation" } },
                 status: :internal_server_error
        end
      end

      private

      def set_list
        @list = List.find(params[:list_id])
      end

      def set_list_share
        @list_share = @list.list_shares.find(params[:id])
      end

      def authorize_list_user
        unless @list.user == current_user
          render json: { error: { message: "Only list user can manage shares" } }, status: :forbidden
        end
      end

      def authorize_share_access
        return if @list.viewable_by?(current_user) || @list_share.user == current_user
        render json: { error: { message: "Unauthorized" } }, status: :forbidden
      end

      def authorize_share_user_or_list_user
        return if @list.user == current_user || @list_share.user == current_user

        # Default: assume they're trying to delete a share they don't own
        render json: { error: { message: "Only list user or share user can delete this share" } }, status: :forbidden
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

      def build_shares_query
        shares = @list.list_shares.includes(:user)

        # Apply status filter
        if params[:status].present?
          status = params[:status].to_s.downcase
          if %w[pending accepted declined].include?(status)
            shares = shares.where(status: status)
          end
        end

        # Apply role filter
        if params[:role].present?
          role = params[:role].to_s.downcase
          if %w[viewer editor admin].include?(role)
            shares = shares.where(role: role)
          end
        end

        # Apply search filter
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          shares = shares.where("email ILIKE ?", search_term)
        end

        # Apply ordering using concern
        valid_columns = %w[email role status invited_at created_at]
        shares = apply_ordering(shares, valid_columns: valid_columns, default_column: "created_at", default_direction: :desc)

        shares
      end

      def validate_share_params
        # Only validate basic format issues, let model validation handle the rest
        # This maintains backward compatibility with existing tests

        # Validate email format if present (allow whitespace that gets normalized)
        if params[:email].present?
          normalized_email = params[:email].to_s.strip.downcase
          unless normalized_email.match?(/\A[^@\s]+@[^@\s]+\z/)
            render json: { error: { message: "Invalid email format" } },
                   status: :bad_request
            return
          end
        end

        # Validate boolean permissions
        boolean_fields = %w[can_view can_edit can_add_items can_delete_items receive_notifications]
        boolean_fields.each do |field|
          if params[field].present?
            value = params[field].to_s.downcase
            unless %w[true false 1 0 t f yes no y n on off].include?(value)
              render json: { error: { message: "Invalid #{field} value" } },
                     status: :bad_request
              return
            end
          end
        end
      end
    end
  end
end
