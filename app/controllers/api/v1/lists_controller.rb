# frozen_string_literal: true

module Api
  module V1
    class ListsController < BaseController
      before_action :set_list, only: %i[show update destroy]
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      # GET /api/v1/lists
      def index
        lists = policy_scope(List)
                  .includes(:user, memberships: :user)

        if params[:since].present?
          since_time = safe_parse_time(params[:since])
          lists = lists.where("lists.updated_at >= ?", since_time) if since_time
        end

        authorize List

        lists = lists.order(updated_at: :desc).to_a
        task_counts_by_list = grouped_task_counts(lists.map(&:id))

        render json: {
          lists: lists.map do |l|
            ListSerializer.new(
              l,
              current_user: current_user,
              task_counts_by_list: task_counts_by_list
            ).as_json
          end,
          tombstones: []
        }, status: :ok
      end

      # GET /api/v1/lists/:id
      def show
        authorize @list
        render json: {
          list: ListSerializer.new(
            @list,
            current_user: current_user,
            include_tasks: true,
            editable_list_ids: editable_list_ids
          ).as_json
        }, status: :ok
      end

      # POST /api/v1/lists
      def create
        authorize List
        list = ListCreationService.call!(user: current_user, params: list_params)
        AnalyticsTracker.list_created(list, current_user)
        render json: { list: ListSerializer.new(list, current_user: current_user).as_json }, status: :created
      end

      # PATCH /api/v1/lists/:id
      def update
        authorize @list
        ListUpdateService.call!(list: @list, user: current_user, attributes: list_params)
        render json: { list: ListSerializer.new(@list, current_user: current_user).as_json }, status: :ok
      end

      # DELETE /api/v1/lists/:id
      def destroy
        authorize @list
        AnalyticsTracker.list_deleted(@list, current_user)
        @list.soft_delete!
        head :no_content
      end

      private

      def set_list
        @list = policy_scope(List).includes(:user, memberships: :user).find(params[:id])
      end

      def list_params
        params.require(:list).permit(:name, :description, :visibility, :color)
      end

      def safe_parse_time(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def editable_list_ids
        @editable_list_ids ||= Membership.where(user_id: current_user.id, role: "editor").pluck(:list_id)
      end

      def grouped_task_counts(list_ids)
        return {} if list_ids.empty?

        counts = list_ids.each_with_object({}) { |list_id, acc| acc[list_id] = { completed: 0, overdue: 0 } }
        base_scope = Task.unscoped.where(list_id: list_ids, deleted_at: nil, parent_task_id: nil)

        completed_counts = base_scope.where(status: :done).group(:list_id).count
        overdue_counts = base_scope.where("due_at IS NOT NULL AND due_at < ?", Time.current)
                                   .where.not(status: :done)
                                   .group(:list_id)
                                   .count

        completed_counts.each do |list_id, count|
          counts[list_id][:completed] = count.to_i
        end
        overdue_counts.each do |list_id, count|
          counts[list_id][:overdue] = count.to_i
        end

        counts
      end
    end
  end
end
