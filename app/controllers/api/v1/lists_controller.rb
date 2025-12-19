# frozen_string_literal: true

module Api
  module V1
    class ListsController <  BaseController
      before_action :authenticate_user!
      before_action :set_list, only: %i[show update destroy]
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      rescue_from ActiveRecord::RecordNotFound do
        render_error("List not found", status: :not_found)
      end

      rescue_from ActionController::ParameterMissing do |e|
        render_error(e.message, status: :bad_request)
      end

      # GET /api/v1/lists
      def index
        lists = policy_scope(List).where(deleted_at: nil)

        if params[:since].present?
          since_time = safe_parse_time(params[:since])
          lists = lists.where("lists.updated_at >= ?", since_time) if since_time
        end

        authorize List

        render json: {
          lists: lists.order(updated_at: :desc).map { |l| ListSerializer.new(l, current_user: current_user).as_json },
          tombstones: [] # TODO: return tombstones if you implement soft-delete syncing
        }, status: :ok
      end

      # GET /api/v1/lists/:id
      def show
        authorize @list

        render json: ListSerializer.new(@list, current_user: current_user, include_tasks: true).as_json, status: :ok
      end

      # POST /api/v1/lists
      def create
        authorize List

        list = ListCreationService.new(user: current_user, params: list_params).create!
        render json: ListSerializer.new(list, current_user: current_user).as_json, status: :created
      rescue ListCreationService::ValidationError => e
        render json: { errors: e.details }, status: :unprocessable_content
      end

      # PATCH /api/v1/lists/:id
      def update
        authorize @list

        ListUpdateService.new(list: @list, user: current_user).update!(attributes: list_params)
        render json: ListSerializer.new(@list, current_user: current_user).as_json, status: :ok
      rescue ListUpdateService::UnauthorizedError => e
        render_error(e.message, status: :forbidden)
      rescue ListUpdateService::ValidationError => e
        render json: { errors: e.details }, status: :unprocessable_content
      end

      # DELETE /api/v1/lists/:id
      def destroy
        authorize @list

        # Keep your current behavior (hard delete) but explicit.
        # If you switch to soft-delete later, replace with update!(deleted_at: Time.current)
        @list.delete
        head :no_content
      end

      # GET /api/v1/lists/validate/:id
      #
      # NOTE: Only keep this if iOS truly needs it. Otherwise delete route + action.
      def validate_access
        list = List.find_by(id: params[:id])
        return render json: { list_id: params[:id], accessible: false, error: "List not found" }, status: :not_found unless list

        accessible = ListPolicy.new(current_user, list).show?
        render json: {
          list_id: list.id,
          accessible: accessible,
          owner: accessible ? list.user&.email : nil
        }, status: :ok
      end

      private

      def set_list
        @list = List.find(params[:id])
      end

      def list_params
        container = params[:list].present? ? params.require(:list) : params
        container.permit(:name, :description, :visibility, :timezone, :latitude, :longitude, :radius_meters)
      end

      def safe_parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def render_error(message, status:)
        render json: { error: { message: message } }, status: status
      end
    end
  end
end
