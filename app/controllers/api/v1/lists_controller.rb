# frozen_string_literal: true

module Api
  module V1
    class ListsController < ApplicationController
      before_action :authenticate_user!

      before_action :set_list, only: %i[
        show update destroy members share unshare tasks
      ]

      before_action :authorize_list_view!,  only: %i[show members tasks]
      before_action :authorize_list_edit!,  only: %i[update]
      before_action :authorize_list_owner!, only: %i[destroy share unshare]

      rescue_from ActiveRecord::RecordNotFound do
        render_error("List not found", status: :not_found)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request)
      end

      rescue_from ListCreationService::ValidationError do |e|
        render json: { errors: e.details }, status: :unprocessable_content
      end

      rescue_from ListUpdateService::UnauthorizedError do |e|
        render_error(e.message, status: :forbidden)
      end

      rescue_from ListUpdateService::ValidationError do |e|
        render json: { errors: e.details }, status: :unprocessable_content
      end

      rescue_from ListSharingService::UnauthorizedError do |e|
        render_error(e.message, status: :forbidden)
      end

      rescue_from ListSharingService::ValidationError do |e|
        render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
      end

      rescue_from ListSharingService::NotFoundError do |e|
        render_error(e.message, status: :not_found)
      end

      # GET /api/v1/lists/validate/:id
      def validate_access
        list = List.find_by(id: params[:id])
        return render json: { list_id: params[:id], accessible: false, error: "List not found" }, status: :not_found unless list

        accessible = can_view?(list)
        render json: {
          list_id: list.id,
          accessible: accessible,
          owner: accessible ? list.user&.email : nil
        }, status: :ok
      end

      # GET /api/v1/lists
      def index
        scope = accessible_lists_scope

        if params[:since].present?
          since_time = safe_parse_time(params[:since])
          scope = scope.where("lists.updated_at >= ?", since_time) if since_time
        end

        active = scope.where(deleted_at: nil)

        render json: {
          lists: active.map { |l| ListSerializer.as_json(l) },
          tombstones: [] # TODO: if you ever soft-delete, return tombstones here
        }, status: :ok
      end

      # GET /api/v1/lists/:id
      def show
        render json: ListSerializer.as_json(@list, include_tasks: true), status: :ok
      end

      # POST /api/v1/lists
      def create
        list = ListCreationService.new(user: current_user, params: list_params).create!
        render json: ListSerializer.as_json(list), status: :created
      end

      # PATCH /api/v1/lists/:id
      def update
        ListUpdateService.new(list: @list, user: current_user).update!(attributes: list_params)
        render json: ListSerializer.as_json(@list), status: :ok
      end

      # DELETE /api/v1/lists/:id
      def destroy
        # Your old code did a hard delete via class.delete (skips callbacks) :contentReference[oaicite:1]{index=1}
        # Keep behavior but make it explicit and safe:
        @list.delete
        head :no_content
      end

      # POST /api/v1/lists/:id/share
      def share
        permissions = share_permissions_params

        share = ListSharingService
                  .new(list: @list, user: current_user)
                  .share!(user_id: params[:user_id], email: params[:email], permissions: permissions)

        render json: ListShareSerializer.as_json(share), status: :created
      end

      # PATCH /api/v1/lists/:id/unshare
      def unshare
        ListSharingService.new(list: @list, user: current_user).unshare!(user_id: params[:user_id])
        render json: ListSerializer.as_json(@list), status: :ok
      end

      # GET /api/v1/lists/:id/members
      def members
        members = []
        members << { id: @list.user_id, role: "owner" }

        @list.list_shares.includes(:user).find_each do |s|
          members << { id: s.user_id, role: "member", can_edit: s.can_edit }
        end

        render json: { members: members }, status: :ok
      end

      # GET /api/v1/lists/:id/tasks
      def tasks
        tasks = @list.tasks.where(deleted_at: nil).order(:due_at)
        render json: { tasks: tasks.map { |t| TaskSerializer.as_json(t) } }, status: :ok
      end

      private

      # -------------------------
      # Finders
      # -------------------------
      def set_list
        # old code used find_by + custom not_found :contentReference[oaicite:2]{index=2}
        @list = List.find(params[:id])
      end

      # -------------------------
      # Authorization
      # -------------------------
      def authorize_list_view!
        return if can_view?(@list)
        render_error("Unauthorized", status: :forbidden)
      end

      def authorize_list_edit!
        return if can_edit?(@list)
        render_error("Unauthorized", status: :forbidden)
      end

      def authorize_list_owner!
        return if owns?(@list)
        render_error("Unauthorized", status: :forbidden)
      end

      def owns?(list) = list.user_id == current_user.id

      def can_view?(list)
        return true if owns?(list)
        ListShare.exists?(
          list_id: list.id,
          user_id: current_user.id,
          status: ListShare.statuses[:accepted]
        )
      end

      def can_edit?(list)
        return true if owns?(list)
        ListShare.exists?(
          list_id: list.id,
          user_id: current_user.id,
          status: ListShare.statuses[:accepted],
          can_edit: true
        )
      end

      # -------------------------
      # Queries
      # -------------------------
      def accessible_lists_scope
        owned_ids  = List.where(user_id: current_user.id).select(:id)
        shared_ids = ListShare.where(
          user_id: current_user.id,
          status: ListShare.statuses[:accepted]
        ).select(:list_id)

        List.where(id: owned_ids).or(List.where(id: shared_ids)).distinct
      end

      def safe_parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      # -------------------------
      # Params
      # -------------------------
      # Old controller supported flat or nested list params :contentReference[oaicite:3]{index=3}
      def list_params
        container = params[:list].present? ? params.require(:list) : params
        container.permit(:name, :description, :visibility)
      end

      def share_permissions_params
        # Old version passed raw strings; normalize to booleans :contentReference[oaicite:4]{index=4}
        fields = %i[can_view can_edit can_add_items can_delete_items]
        fields.to_h { |k| [k, cast_bool(params[k])] }
      end

      def cast_bool(value)
        case value
        when true, false then value
        when nil, ""     then false
        else
          value.to_s.strip.downcase.in?(%w[true 1 t yes y on])
        end
      end

      # -------------------------
      # Rendering helpers
      # -------------------------
      def render_error(message, status:)
        render json: { error: { message: message } }, status: status
      end
    end
  end
end

# --- Plain Ruby serializers (keep in app/serializers) ---

class ListSerializer
  def self.as_json(list, include_tasks: false)
    payload = {
      id: list.id,
      name: list.name,
      description: list.description,
      visibility: list.visibility,
      user_id: list.user_id,
      deleted_at: list.deleted_at,
      created_at: list.created_at,
      updated_at: list.updated_at
    }

    if include_tasks
      tasks = list.tasks.where(deleted_at: nil).order(:due_at)
      payload[:tasks] = tasks.map { |t| TaskSerializer.as_json(t) }
    end

    payload
  end
end

class TaskSerializer
  def self.as_json(task)
    {
      id: task.id,
      title: task.title,
      note: task.note,
      due_at: task.due_at,
      status: task.status,
      created_at: task.created_at,
      updated_at: task.updated_at
    }
  end
end

class ListShareSerializer
  def self.as_json(share)
    {
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
    }
  end
end
