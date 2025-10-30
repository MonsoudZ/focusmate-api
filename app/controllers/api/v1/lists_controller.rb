# app/controllers/api/v1/lists_controller.rb
module Api
  module V1
    class ListsController < ApplicationController
      before_action :set_list, only: [ :show, :update, :destroy, :members, :share, :unshare, :tasks ]
      before_action :authorize_list_view!, only: [ :show, :members, :tasks ]
      before_action :authorize_list_edit!, only: [ :update ]
      before_action :authorize_list_owner!, only: [ :destroy, :share, :unshare ]

      # GET /api/v1/lists/validate/:id (convenience check)
      def validate_access
        list = List.find_by(id: params[:id])
        unless list
          return render json: { list_id: params[:id], accessible: false, error: "List not found" }, status: :not_found
        end

        can_access = can_view?(list)
        render json: {
          list_id: list.id,
          accessible: can_access,
          owner: can_access ? list.user&.email : nil
        }, status: :ok
      end

      # GET /api/v1/lists
      def index
        owned_ids  = List.where(user_id: current_user.id).select(:id)
        shared_ids = ListShare.where(user_id: current_user.id, status: ListShare.statuses[:accepted]).select(:list_id)
        scope = List.where(id: owned_ids).or(List.where(id: shared_ids)).distinct

        # since filter (optional)
        if params[:since].present?
          since_time =
            begin
              Time.zone.parse(params[:since])
            rescue ArgumentError, TypeError
              nil
            end
          scope = scope.where("lists.updated_at >= ?", since_time) if since_time
        end

        active = scope.where(deleted_at: nil)

        render json: { lists: active.map { |l| serialize_list(l) }, tombstones: [] }, status: :ok
      end

      # GET /api/v1/lists/:id
      def show
        render json: serialize_list(@list, include_tasks: true), status: :ok
      end

      # POST /api/v1/lists
      def create
        service = ListCreationService.new(user: current_user, params: list_params_flat)
        list = service.create!
        render json: serialize_list(list), status: :created
      rescue ListCreationService::ValidationError => e
        render json: { errors: e.details }, status: :unprocessable_content
      end

      # PATCH /api/v1/lists/:id
      def update
        service = ListUpdateService.new(list: @list, user: current_user)
        service.update!(attributes: list_params_flat)
        render json: serialize_list(@list), status: :ok
      rescue ListUpdateService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue ListUpdateService::ValidationError => e
        render json: { errors: e.details }, status: :unprocessable_content
      end

      # DELETE /api/v1/lists/:id
      def destroy
        @list.class.delete(@list.id)
        head :no_content
      end

      # POST /api/v1/lists/:id/share
      # params: user_id or email (required), can_edit (optional)
      def share
        service = ListSharingService.new(list: @list, user: current_user)
        permissions = {
          can_view: params[:can_view],
          can_edit: params[:can_edit],
          can_add_items: params[:can_add_items],
          can_delete_items: params[:can_delete_items]
        }
        share = service.share!(user_id: params[:user_id], email: params[:email], permissions: permissions)

        render json: {
          id: share.id,
          user_id: share.user_id,
          email: share.email,
          can_view: share.can_view,
          can_edit: share.can_edit,
          can_add_items: share.can_add_items,
          can_delete_items: share.can_delete_items,
          status: share.status,
          created_at: share.created_at,
          updated_at: share.updated_at
        }, status: :created
      rescue ListSharingService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue ListSharingService::ValidationError => e
        render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
      rescue ListSharingService::NotFoundError => e
        render json: { error: { message: e.message } }, status: :not_found
      end

      # PATCH /api/v1/lists/:id/unshare
      # params: user_id (required)
      def unshare
        service = ListSharingService.new(list: @list, user: current_user)
        service.unshare!(user_id: params[:user_id])
        render json: serialize_list(@list), status: :ok
      rescue ListSharingService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue ListSharingService::ValidationError => e
        render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
      end

      # GET /api/v1/lists/:id/members
      def members
        owner = { id: @list.user_id, role: "owner" }
        shared_members = @list.list_shares.includes(:user).map do |s|
          { id: s.user_id, role: "member", can_edit: s.can_edit }
        end
        all_members = [ owner ] + shared_members
        render json: { members: all_members }, status: :ok
      end

      # GET /api/v1/lists/:id/tasks
      def tasks
        tasks = @list.tasks.where(deleted_at: nil).order(:due_at)
        render json: {
          tasks: tasks.map do |t|
            {
              id: t.id,
              title: t.title,
              note: t.note,
              due_at: t.due_at,
              status: t.status,
              created_at: t.created_at,
              updated_at: t.updated_at
            }
          end
        }, status: :ok
      end

      private

      # === Auth & authz helpers ===

      def require_auth!
        return if current_user.present?
        render json: { error: { message: "Unauthorized" } }, status: :unauthorized
      end

      def set_list
        @list = List.find_by(id: params[:id])
        not_found unless @list
      end

      def authorize_list_view!
        return if can_view?(@list)
        forbidden
      end

      def authorize_list_edit!
        return if can_edit?(@list)
        forbidden
      end

      def authorize_list_owner!
        return if owns?(@list)
        forbidden
      end

      def owns?(list)
        list.user_id == current_user.id
      end

      def can_view?(list)
        return true if owns?(list)
        ListShare.exists?(list_id: list.id,
                          user_id: current_user.id,
                          status: ListShare.statuses[:accepted])
      end

      def can_edit?(list)
        return true if owns?(list)
        ListShare.exists?(list_id: list.id,
                          user_id: current_user.id,
                          status: ListShare.statuses[:accepted],
                          can_edit: true)
      end

      # === Params & serializers ===

      # Specs send flat params; support both flat and nested.
      def list_params_flat
        if params[:list].present?
          params.require(:list).permit(:name, :description, :visibility)
        else
          params.permit(:name, :description, :visibility)
        end
      end

      def serialize_list(l, include_tasks: false)
        payload = {
          id: l.id,
          name: l.name,
          description: l.description,
          visibility: l.visibility,
          user_id: l.user_id,
          deleted_at: l.deleted_at,
          created_at: l.created_at,
          updated_at: l.updated_at
        }
        if include_tasks
          tasks = l.tasks.where(deleted_at: nil).order(:due_at)
          payload[:tasks] = tasks.map do |t|
            {
              id: t.id, title: t.title, note: t.note, due_at: t.due_at,
              status: t.status, created_at: t.created_at, updated_at: t.updated_at
            }
          end
        end
        payload
      end

      # === Error helpers (match spec shapes) ===

      def not_found
        render json: { error: { message: "List not found" } }, status: :not_found
      end

      def forbidden
        render json: { error: { message: "Unauthorized" } }, status: :forbidden
      end

      def bad_request
        render json: { error: { message: "Bad Request" } }, status: :bad_request
      end

      def validation_error!(record)
        render json: { errors: record.errors.as_json },
               status: :unprocessable_content
      end

      def validation_error_message!(msg)
        render json: { error: { message: "Validation failed", details: { base: [ msg ] } } },
               status: :unprocessable_content
      end
    end
  end
end
