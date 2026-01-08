# frozen_string_literal: true

module Api
  module V1
    class TasksController < BaseController
      include Paginatable

      before_action :set_list, only: [ :index, :create, :reorder ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :reopen, :snooze, :assign, :unassign ]

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
        AnalyticsTracker.task_deleted(@task, current_user)
        @task.soft_delete!
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

        snooze_count = AnalyticsEvent.where(task: @task, event_type: "task_snoozed").count + 1

        new_due = (@task.due_at || Time.current) + duration.minutes
        @task.update!(due_at: new_due)

        AnalyticsTracker.task_snoozed(@task, current_user, duration_minutes: duration, snooze_count: snooze_count)

        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id/assign
      def assign
        authorize @task, :update?
        unless params[:assigned_to].present?
          return render json: { error: { message: "assigned_to is required" } }, status: :bad_request
        end

        # Validate assignee has access to the list
        assignee = User.find_by(id: params[:assigned_to])
        unless assignee && @task.list.accessible_by?(assignee)
          return render json: { error: { message: "User cannot be assigned to this task" } }, status: :unprocessable_entity
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

      # POST /api/v1/lists/:list_id/tasks/reorder
      def reorder
        authorize @list, :update?

        params[:tasks].each do |task_data|
          task = @list.tasks.find(task_data[:id])
          task.update!(position: task_data[:position])
        end

        head :ok
      end

      # GET /api/v1/tasks/search?q=query
      def search
        query = params[:q].to_s.strip

        if query.blank?
          skip_policy_scope
          return render json: { tasks: [] }, status: :ok
        end

        tasks = policy_scope(Task)
                  .where("title ILIKE :q OR note ILIKE :q", q: "%#{query}%")
                  .where(parent_task_id: nil)
                  .not_deleted
                  .includes(:list)
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
          notification_interval_minutes list_id visibility color starred position
          is_recurring recurrence_pattern recurrence_interval recurrence_end_date recurrence_count recurrence_time
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
