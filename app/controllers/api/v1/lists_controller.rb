# frozen_string_literal: true

module Api
  module V1
    class ListsController < BaseController
      before_action :set_list, only: %i[show update destroy]
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

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
          tombstones: []
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
      end

      # PATCH /api/v1/lists/:id
      def update
        authorize @list
        ListUpdateService.new(list: @list, user: current_user).update!(attributes: list_params)
        render json: ListSerializer.new(@list, current_user: current_user).as_json, status: :ok
      end

      # DELETE /api/v1/lists/:id
      def destroy
        authorize @list
        @list.destroy
        head :no_content
      end

      private

      def set_list
        @list = List.find(params[:id])
      end

      def list_params
        container = params[:list].present? ? params.require(:list) : params
        container.permit(:name, :description, :visibility, :color)
      end

      def safe_parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
