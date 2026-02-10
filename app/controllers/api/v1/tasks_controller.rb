# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      include Paginatable
      include EditableLists

      before_action :set_list, only: [ :index, :create, :reorder ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :reopen, :assign, :unassign, :nudge, :reschedule ]

      after_action :verify_authorized, except: [ :index, :search ]
      after_action :verify_policy_scoped, only: [ :index, :search ]

      # GET /api/v1/tasks
      def index
        tasks = policy_scope(Task)

        if params[:list_id]
          tasks = tasks.where(list_id: @list.id)
        end

        tasks = tasks.where(parent_task_id: nil).where(is_template: [ false, nil ])
        tasks = apply_filters(tasks)
        tasks = apply_ordering(tasks)
        tasks = tasks.includes(:tags, :creator, :subtasks, :list)
        result = paginate(tasks, page: params[:page], per_page: params[:per_page])

        render json: {
          tasks: result[:records].map do |t|
            TaskSerializer.new(
              t,
              current_user: current_user,
              include_reschedule_events: false,
              editable_list_ids: editable_list_ids
            ).as_json
          end,
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
          return render_error("Bad Request", status: :bad_request, code: "empty_body")
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
          missed_reason: completion_params[:missed_reason]
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
        TaskAssignmentService.assign!(task: @task, user: current_user, assigned_to_id: assignment_params[:assigned_to])
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

      # POST /api/v1/lists/:list_id/tasks/:id/reschedule
      def reschedule
        authorize @task, :update?
        TaskRescheduleService.call!(
          task: @task,
          user: current_user,
          new_due_at: reschedule_params[:new_due_at],
          reason: reschedule_params[:reason]
        )
        @task.reload
        render json: { task: TaskSerializer.new(@task, current_user: current_user).as_json }
      end

      # POST /api/v1/lists/:list_id/tasks/reorder
      def reorder
        authorize @list, :update?
        TaskReorderService.call!(list: @list, task_positions: reorder_task_positions)
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
          return render_error("Search query too long (max 255 characters)", status: :bad_request, code: "query_too_long")
        end

        # Escape LIKE special characters to prevent unexpected matching
        escaped_query = Task.sanitize_sql_like(query)

        tasks = policy_scope(Task)
                  .where("title ILIKE :q OR note ILIKE :q", q: "%#{escaped_query}%")
                  .where(parent_task_id: nil)
                  .includes(:tags, :creator, :subtasks, :list)
                  .limit(50)

        render json: {
          tasks: tasks.map do |t|
            TaskSerializer.new(
              t,
              current_user: current_user,
              include_reschedule_events: false,
              editable_list_ids: editable_list_ids
            ).as_json
          end
        }, status: :ok
      end

      private

      def set_list
        list_id = params[:list_id] || params[:listId]

        if list_id.present?
          @list = policy_scope(List).not_deleted.find(list_id)
        end
      end

      def set_task
        scope = policy_scope(Task).includes(:tags, :creator, :subtasks, :list, reschedule_events: :user)
        scope = scope.where(list_id: params[:list_id]) if params[:list_id].present?
        @task = scope.find(params[:id])
      end

      def empty_json_body?
        request.content_type&.include?("application/json") && request.raw_post.to_s.strip.empty?
      end

      def task_params
        permitted = action_name == "create" ? permitted_create_attributes : permitted_update_attributes
        p = params.require(:task).permit(permitted)
        if p.key?(:hidden)
          hidden = ActiveModel::Type::Boolean.new.cast(p.delete(:hidden))
          p[:visibility] = hidden ? :private_task : :visible_to_all
        end
        p
      end

      def reorder_task_positions
        tasks = params.require(:tasks)
        raise ApplicationError::BadRequest, "tasks must be an array" unless tasks.is_a?(Array)

        tasks.map do |entry|
          entry_params =
            if entry.is_a?(ActionController::Parameters)
              entry
            elsif entry.is_a?(Hash)
              ActionController::Parameters.new(entry)
            else
              raise ApplicationError::BadRequest, "each task entry must be an object"
            end

          permitted = entry_params.permit(:id, :position)
          id = permitted[:id]
          position = permitted[:position]

          if id.blank? || position.nil?
            raise ApplicationError::BadRequest, "each task entry must include id and position"
          end

          {
            id: parse_integer!(id, field: "id"),
            position: parse_integer!(position, field: "position")
          }
        end
      end

      def parse_integer!(value, field:)
        parsed = Integer(value, exception: false)
        raise ApplicationError::BadRequest, "#{field} must be an integer" if parsed.nil?

        parsed
      end

      def completion_params
        params.permit(:missed_reason)
      end

      def assignment_params
        params.permit(:assigned_to)
      end

      def reschedule_params
        params.permit(:new_due_at, :reason)
      end

      def permitted_base_attributes
        %i[
          title note due_at priority strict_mode hidden
          notification_interval_minutes visibility color starred position
          is_recurring recurrence_pattern recurrence_interval recurrence_end_date recurrence_count recurrence_time
        ] + [ tag_ids: [], recurrence_days: [] ]
      end

      def permitted_create_attributes
        permitted_base_attributes + %i[list_id parent_task_id]
      end

      def permitted_update_attributes
        permitted_base_attributes
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
