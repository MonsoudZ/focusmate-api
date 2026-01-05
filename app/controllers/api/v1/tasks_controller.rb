# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      include Paginatable

      before_action :set_list, only: [ :index, :create ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :reopen, :snooze, :assign, :unassign ]

      after_action :verify_authorized, except: [ :index ]
      after_action :verify_policy_scoped, only: [ :index ]

      # GET /api/v1/tasks
      def index
        tasks = policy_scope(Task)

        if params[:list_id]
          tasks = tasks.where(list_id: @list.id)
        end

        tasks = tasks.where(parent_task_id: nil).not_deleted
        tasks = apply_filters(tasks)
        tasks = apply_ordering(tasks)
        result = paginate(tasks, page: params[:page], per_page: params[:per_page])

        render json: {
          tasks: result[:records].map { |t| TaskSerializer.new(t, current_user: current_user).as_json },
          tombstones: [],
          pagination: result[:pagination]
        }, status: :ok
      end

      # GET /api/v1/lists/:list_id/tasks/:id
      def show
        authorize @task
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # POST /api/v1/lists/:list_id/tasks
      def create
        if empty_json_body?
          return render json: { error: { message: "Bad Request" } }, status: :bad_request
        end

        @list ||= current_user.owned_lists.first
        authorize @list, :create_task?

        task = TaskCreationService.new(@list, current_user, task_params).call
        render json: TaskSerializer.new(task, current_user: current_user).as_json, status: :created
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id
      def update
        authorize @task
        TaskUpdateService.new(task: @task, user: current_user).update!(attributes: task_params)
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # DELETE /api/v1/lists/:list_id/tasks/:id
      def destroy
        authorize @task
        @task.destroy
        head :no_content
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/complete
      def complete
        authorize @task, :update?

        begin
          TaskCompletionService.new(
            task: @task,
            user: current_user,
            missed_reason: params[:missed_reason]
          ).complete!
          render json: TaskSerializer.new(@task, current_user: current_user).as_json
        rescue TaskCompletionService::MissingReasonError => e
          render json: { error: { code: "missing_reason", message: e.message } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/reopen
      def reopen
        authorize @task, :update?
        TaskCompletionService.new(task: @task, user: current_user).uncomplete!
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/snooze
      def snooze
        authorize @task, :update?
        duration = params[:duration].to_i
        duration = 60 if duration <= 0

        new_due = (@task.due_at || Time.current) + duration.minutes
        @task.update!(due_at: new_due)

        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/assign
      def assign
        authorize @task, :update?
        unless params[:assigned_to].present?
          return render json: { error: { message: "assigned_to is required" } }, status: :bad_request
        end

        @task.update!(assigned_to_id: params[:assigned_to])
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/unassign
      def unassign
        authorize @task, :update?
        @task.update!(assigned_to_id: nil)
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      private

      def set_list
        list_id = params[:list_id] || params[:listId]

        if list_id.present?
          @list = List.find(list_id)
          unless @list.accessible_by?(current_user)
            render json: { error: { message: "Forbidden" } }, status: :forbidden
          end
        end
      end

      def set_task
        @task = Task.find(params[:id])
      end

      def empty_json_body?
        request.content_type&.include?("application/json") && request.raw_post.to_s.strip.empty?
      end

      def task_params
        if params[:task].present?
          params.require(:task).permit(permitted_task_attributes)
        else
          params.permit(permitted_task_attributes)
        end
      end

      def permitted_task_attributes
        %i[
    title note due_at priority can_be_snoozed strict_mode
    notification_interval_minutes list_id visibility color
  ]
      end

      def apply_filters(query)
        return query unless params[:status].present?

        case params[:status]
        when "pending" then query.where(status: "pending")
        when "completed", "done" then query.where(status: "done")
        when "overdue" then query.where("due_at < ?", Time.current).where.not(status: "done")
        else query
        end
      end

      def apply_ordering(query)
        order(
          query,
          order_by: params[:sort_by],
          order_direction: params[:sort_order],
          valid_columns: %w[created_at updated_at due_at title],
          default_column: :created_at,
          default_direction: :desc
        )
      end
    end
  end
end
