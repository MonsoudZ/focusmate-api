# app/controllers/api/v1/tasks_controller.rb
module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_list, only: [ :index, :create ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :uncomplete, :reassign, :submit_explanation, :toggle_visibility, :add_subtask, :update_subtask, :delete_subtask, :change_visibility ]
      before_action :authorize_task_access, only: [ :show ]
      before_action :authorize_task_edit, only: [ :update, :destroy ]
      before_action :authorize_task_visibility_change, only: [ :change_visibility ]

      # GET /api/v1/lists/:list_id/tasks
      def index
        # Minimal, non-500 implementation; expand as your spec requires.
        tasks = @list.tasks.where(parent_task_id: nil).not_deleted
        render json: {
          tasks: tasks.map { |task|
            {
              id: task.id,
              title: task.title,
              status: task.status,
              created_at: task.created_at.iso8601,
              updated_at: task.updated_at.iso8601
            }
          },
          tombstones: []
        }, status: :ok
      end

      # GET /api/v1/tasks - Get all tasks across all lists for current user
      def all_tasks
        # Minimal, non-500 implementation; expand as your spec requires.
        tasks = Task.joins(:list).where(lists: { user_id: current_user.id }).where(parent_task_id: nil)

        # Apply simple filters
        if params[:status].present?
          case params[:status]
          when "pending"
            tasks = tasks.where(status: "pending")
          when "completed", "done"
            tasks = tasks.where(status: "done")
          when "overdue"
            tasks = tasks.where("due_at < ?", Time.current).where.not(status: "done")
          end
        end

        render json: {
          tasks: tasks.map { |task|
            {
              id: task.id,
              title: task.title,
              status: task.status,
              created_at: task.created_at.iso8601,
              updated_at: task.updated_at.iso8601
            }
          },
          tombstones: []
        }, status: :ok
      end

      # GET /api/v1/lists/:list_id/tasks/:id
      def show
        render json: TaskSerializer.new(@task, current_user: current_user, include_subtasks: true).as_json
      end

        # POST /api/v1/lists/:list_id/tasks
        def create
          # Handle empty request body
          if request.content_type&.include?("application/json") && request.raw_post.to_s.strip.empty?
            return render json: { error: "Bad Request" }, status: :bad_request
          end

          # Debug logging for iOS app issues
          Rails.logger.info "Task creation request - Raw params: #{params.inspect}"
          Rails.logger.info "Task creation request - Parsed task_params: #{task_params.inspect}"

          unless @list.can_add_items_by?(current_user)
            # Try to find a list the user can add items to
            fallback_list = current_user.owned_lists.first
            if fallback_list && fallback_list.can_add_items_by?(current_user)
              @list = fallback_list
              Rails.logger.info "Redirected task creation from list #{params[:list_id]} to list #{@list.id} for user #{current_user.id}"
            else
              return render_forbidden("You do not have permission to add tasks to this list")
            end
          end

          begin
            @task = TaskCreationService.new(@list, current_user, task_params).call
            render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :created
          rescue ActiveRecord::RecordInvalid => e
            Rails.logger.error "Task creation validation failed: #{e.record.errors.full_messages}"
            render json: { error: "Validation failed", details: e.record.errors.to_hash }, status: :unprocessable_entity
          rescue => e
            Rails.logger.error "Task creation failed: #{e.message}"
            Rails.logger.error "Task params: #{task_params.inspect}"
            render_server_error("Failed to create task")
          end
        end

      # PATCH /api/v1/lists/:list_id/tasks/:id
      def update
        if @task.update(task_params)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json
        else
          render_validation_errors(@task.errors)
        end
      end

      # DELETE /api/v1/lists/:list_id/tasks/:id
      def destroy
        @task.destroy
        head :no_content
      end

      # POST /api/v1/tasks/:id/complete
      def complete
        unless can_access_task?(@task)
          render json: {
            error: "Unauthorized",
            message: "You do not have permission to modify this task",
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }, status: :forbidden
          return
        end

        # Handle both completion states based on the completed parameter
        if params[:completed] == false || params[:completed] == "false"
          @task.uncomplete!
        else
          @task.complete!
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      end

      # PATCH /api/v1/tasks/:id/uncomplete
      def uncomplete
        unless can_access_task?(@task)
          render json: {
            error: "Unauthorized",
            message: "You do not have permission to modify this task",
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }, status: :forbidden
          return
        end

        @task.uncomplete!

        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      end

      # POST /api/v1/tasks/:id/reassign
      # PATCH /api/v1/tasks/:id/reassign
      def reassign
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        uid = params[:assigned_to]

        if Task.column_names.include?("assigned_to_id")
          @task.update!(assigned_to_id: uid)
        elsif Task.column_names.include?("assigned_to")
          @task.update!(assigned_to: uid)
        else
          render json: { error: { message: "Task does not support assignment" } }, status: :unprocessable_content
          return
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      end

      # POST /api/v1/tasks/:id/submit_explanation
      def submit_explanation
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        attrs = {}
        if Task.column_names.include?("missed_reason")
          attrs[:missed_reason] = params[:missed_reason].to_s
        end
        if Task.column_names.include?("missed_reason_submitted_at")
          attrs[:missed_reason_submitted_at] = Time.current
        end

        if attrs.empty?
          render json: { error: { message: "Task does not support missed-explanation fields" } }, status: :unprocessable_content
          return
        end

        if @task.update(attrs)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          render json: { errors: @task.errors.to_hash }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/tasks/:id/toggle_visibility
      def toggle_visibility
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        visibility = params[:visibility]

        if visibility.present?
          # Handle visibility parameter (for change_visibility-style calls)
          unless Task.visibilities.keys.include?(visibility)
            return render json: { error: "Invalid visibility setting" }, status: :bad_request
          end

          @task.update!(visibility: visibility)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          # Handle coach_id/visible parameters (for toggle_visibility-style calls)
          coach_id = params[:coach_id]
          visible = params[:visible]

          coach = User.find(coach_id)
          relationship = current_user.relationship_with_coach(coach)

          unless relationship
            return render json: { error: "Not Found" }, status: :not_found
          end

          if visible
            @task.show_to!(relationship)
          else
            @task.hide_from!(relationship)
          end

          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        end
      end

      # PATCH /api/v1/tasks/:id/change_visibility
      def change_visibility
        visibility = params[:visibility]

        unless %w[visible hidden coaching_only].include?(visibility)
          return render_bad_request("Invalid visibility setting")
        end

        case visibility
        when "visible"
          @task.make_visible!
        when "hidden"
          @task.make_hidden!
        when "coaching_only"
          @task.make_coaching_only!
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # POST /api/v1/tasks/:id/add_subtask
      def add_subtask
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        due_time = parse_iso(params[:due_at])
        if Task.validators_on(:due_at).any? { |v| v.kind == :presence } && due_time.nil?
          return render json: { errors: { due_at: [ "is invalid or missing" ] } }, status: :unprocessable_content
        end

        sub_attrs = {
          title:        params.require(:title),
          note:         params[:note],
          due_at:       due_time,
          list_id:      @task.list_id,
          creator_id:   current_user.id,
          strict_mode:  true
        }

        # prefer parent_task_id, fall back to parent_task association if you use that
        if Task.column_names.include?("parent_task_id")
          sub_attrs[:parent_task_id] = @task.id
        end

        sub = Task.new(sub_attrs)

        if sub.save
          render json: TaskSerializer.new(sub, current_user: current_user).as_json.merge(parent_task_id: @task.id), status: :created
        else
          render json: { errors: sub.errors.to_hash }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/tasks/:id/subtasks/:subtask_id
      def update_subtask
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        if @task.update(task_params)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          render json: { errors: @task.errors.to_hash }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/tasks/:id/subtasks/:subtask_id
      def delete_subtask
        unless @task.list.user_id == current_user.id
          render json: { error: "Forbidden" }, status: :forbidden
          return
        end

        @task.destroy
        head :no_content
      end

      # GET /api/v1/tasks/blocking
      def blocking
        @tasks = current_user.owned_lists
                            .joins(tasks: :escalation)
                            .where(item_escalations: { blocking_app: true })
                            .where(tasks: { completed_at: nil })
                            .includes(:creator, :subtasks)

        render json: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
      end

      # GET /api/v1/tasks/awaiting_explanation
      def awaiting_explanation
        @tasks = Task.joins(:list)
                     .where(lists: { user_id: current_user.id })
                     .awaiting_explanation
                     .includes(:creator, :list)

        render json: { tasks: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json } }
      end

      # GET /api/v1/tasks/overdue
      def overdue
        @tasks = Task.joins(:list)
                     .where(lists: { user_id: current_user.id })
                     .overdue
                     .includes(:creator, :list, :escalation)
                     .order(due_at: :asc)

        render json: { tasks: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json } }
      end

      private

      def set_list
        list_id = params[:list_id]
        list_id ||= params[:listId]
        list_id ||= params.dig(:task, :list_id) if params[:task].is_a?(ActionController::Parameters)
        list_id ||= params.dig(:task, :listId) if params[:task].is_a?(ActionController::Parameters)
        list_id ||= params.dig(:list, :id) if params[:list].is_a?(ActionController::Parameters)

        # Fallback: use user's first list if no list_id provided
        if list_id.blank?
          @list = current_user.owned_lists.first
          if @list.nil?
            raise ActiveRecord::RecordNotFound, "No list found. Please create a list first or specify a list_id."
          end
        else
          begin
            @list = List.find(list_id)
            # Check if user has access to this list
            unless @list.can_view?(current_user)
              render json: { error: { message: "List not found" } }, status: :forbidden
              nil
            end
          rescue ActiveRecord::RecordNotFound => e
            Rails.logger.warn "List not found: User #{current_user.id} tried to access list #{list_id}"
            render json: { error: { message: "List not found" } }, status: :not_found
            nil
          end
        end
      end

      def set_task
        begin
          if params[:list_id]
            @task = Task.find(params[:id])
          else
            @task = Task.find(params[:id])
          end
        rescue ActiveRecord::RecordNotFound
          render_not_found("Task")
        end
      end

      def authorize_task_access
        unless @task.list.can_view?(current_user) && @task.visible_to?(current_user)
          render json: { error: { message: "List not found" } }, status: :forbidden
        end
      end

      def authorize_task_edit
        unless @task.editable_by?(current_user)
          render json: { error: { message: "List not found" } }, status: :forbidden
        end
      end

      def task_params
        # Handle both nested task params and direct params (iOS app)
        if params[:task].present?
          params.require(:task).permit(
            :title, :note, :due_at, :priority, :can_be_snoozed, :strict_mode,
            :notification_interval_minutes, :requires_explanation_if_missed,
            :is_recurring, :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
            :location_based, :location_latitude, :location_longitude, :location_radius_meters,
            :location_name, :notify_on_arrival, :notify_on_departure,
            :list_id, :creator_id, :visibility,
            { recurrence_days: [] }
          )
        else
          # Handle direct params from iOS app - be more permissive to handle parameter pollution
          begin
            params.permit(
              :title, :note, :due_at, :priority, :can_be_snoozed, :strict_mode,
              :notification_interval_minutes, :requires_explanation_if_missed,
              :is_recurring, :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
              :location_based, :location_latitude, :location_longitude, :location_radius_meters,
              :location_name, :notify_on_arrival, :notify_on_departure,
              :list_id, :creator_id, :name, :dueDate, :description, :due_date, :visibility,
              { recurrence_days: [] }
            )
          rescue ActionController::UnpermittedParameters => e
            # Log but don't fail - this handles parameter pollution gracefully
            Rails.logger.warn "Unpermitted parameters detected: #{e.params.join(', ')}"
            params.permit(
              :title, :note, :due_at, :priority, :can_be_snoozed, :strict_mode,
              :notification_interval_minutes, :requires_explanation_if_missed,
              :is_recurring, :recurrence_pattern, :recurrence_interval, :recurrence_time, :recurrence_end_date,
              :location_based, :location_latitude, :location_longitude, :location_radius_meters,
              :location_name, :notify_on_arrival, :notify_on_departure,
              :list_id, :creator_id, :name, :dueDate, :description, :due_date, :visibility,
              { recurrence_days: [] }
            )
          end
        end
      end

      def can_access_task?(task)
        # Check if user owns the list
        return true if task.list.user_id == current_user.id

        # Check if user created the task
        return true if task.creator_id == current_user.id

        # Check if user is a member/coach of the list
        return true if task.list.memberships.exists?(user_id: current_user.id)

        false
      end

      def authorize_task_visibility_change
        unless @task.can_change_visibility?(current_user)
          render_forbidden("You do not have permission to change task visibility")
        end
      end

      def parse_iso(date_string)
        return nil if date_string.blank?
        Time.parse(date_string)
      rescue ArgumentError
        nil
      end
    end
  end
end
