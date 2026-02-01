# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      include Paginatable

      before_action :set_list, only: [ :index, :create, :reorder ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :reopen, :assign, :unassign, :nudge ]

      after_action :verify_authorized, except: [ :index, :search ]
      after_action :verify_policy_scoped, only: [ :index, :search ]

      # GET /api/v1/tasks
      def index
        tasks = policy_scope(Task)

        if params[:list_id]
          tasks = tasks.where(list_id: @list.id)
        end

        tasks = tasks.where(parent_task_id: nil).where(is_template: [ false, nil ]).not_deleted
        tasks = apply_filters(tasks)
        tasks = apply_ordering(tasks)
        tasks = tasks.includes(:tags, :creator, :subtasks, list: :user)
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
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # POST /api/v1/lists/:list_id/tasks
      def create
        if empty_json_body?
          return render json: { error: { message: "Bad Request" } }, status: :bad_request
        end

        @list ||= current_user.owned_lists.first
        authorize @list, :create_task?

        task = TaskCreationService.call!(list: @list, user: current_user, params: task_params)
        render json: { task: TaskSerializer.new(task, current_user: current_user).as_json }, status: :created
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id
      def update
        authorize @task
        TaskUpdateService.call!(task: @task, user: current_user, attributes: task_params)
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # DELETE /api/v1/lists/:list_id/tasks/:id
      def destroy
        authorize @task
        AnalyticsTracker.task_deleted(@task, current_user)
        @task.soft_delete!
        head :no_content
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/complete
      def complete
        authorize @task, :update?

        TaskCompletionService.complete!(
          task: @task,
          user: current_user,
          missed_reason: params[:missed_reason]
        )
        @task.reload
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/reopen
      def reopen
        authorize @task, :update?
        TaskCompletionService.uncomplete!(task: @task, user: current_user)
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/assign
      def assign
        authorize @task, :update?
        TaskAssignmentService.assign!(task: @task, user: current_user, assigned_to_id: params[:assigned_to])
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/unassign
      def unassign
        authorize @task, :update?
        TaskAssignmentService.unassign!(task: @task, user: current_user)
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # POST /api/v1/lists/:list_id/tasks/:id/nudge
      def nudge
        authorize @task, :nudge?
        TaskNudgeService.call!(task: @task, from_user: current_user)
        render json: { message: "Nudge sent" }, status: :ok
      end

      # POST /api/v1/lists/:list_id/tasks/reorder
      def reorder
        authorize @list, :update?
        TaskReorderService.call!(list: @list, task_positions: params[:tasks].map { |t| t.permit(:id, :position).to_h.symbolize_keys })
        head :ok
      end

      # GET /api/v1/tasks/search?q=query
      def search
        query = params[:q].to_s.strip

        if query.blank?
          skip_policy_scope
          return render json: { tasks: [] }, status: :ok
        end

        if query.length > 255
          skip_policy_scope
          return render json: { error: { message: "Search query too long (max 255 characters)" } }, status: :bad_request
        end

        tasks = policy_scope(Task)
                  .where("title ILIKE :q OR note ILIKE :q", q: "%#{query}%")
                  .where(parent_task_id: nil)
                  .not_deleted
                  .includes(:tags, :creator, :subtasks, list: :user)
                  .limit(50)

        render json: {
          tasks: tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json }
        }, status: :ok
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
        @task = policy_scope(Task).includes(:tags, :creator, :subtasks, list: :user).find(params[:id])
      end

      def empty_json_body?
        request.content_type&.include?("application/json") && request.raw_post.to_s.strip.empty?
      end

      def task_params
        params.require(:task).permit(permitted_task_attributes)
      end

      def permitted_task_attributes
        %i[
          title note due_at priority strict_mode
          notification_interval_minutes list_id visibility color starred position
          is_recurring recurrence_pattern recurrence_interval recurrence_end_date recurrence_count recurrence_time
          parent_task_id
        ] + [ tag_ids: [], recurrence_days: [] ]
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
        col = %w[created_at updated_at due_at title].include?(params[:sort_by].to_s) ? params[:sort_by].to_s : "created_at"
        dir = %w[asc desc].include?(params[:sort_order].to_s.downcase) ? params[:sort_order].to_s.downcase.to_sym : :desc

        query.sorted_with_priority(col, dir)
      end
    end
  end
end
