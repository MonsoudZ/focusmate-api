module Api
  module V1
    class TasksController < ApplicationController
      before_action :authenticate_user!
      before_action :set_list, only: [ :index, :create ]
      before_action :set_task, only: [ :show, :update, :destroy, :complete, :uncomplete, :reassign, :submit_explanation, :toggle_visibility, :add_subtask, :update_subtask, :delete_subtask, :change_visibility ]
      before_action :authorize_task_access, only: [ :show ]
      before_action :authorize_task_edit, only: [ :update, :destroy ]
      before_action :authorize_task_visibility_change, only: [ :change_visibility ]
      before_action :validate_params, only: [ :index, :all_tasks, :overdue, :awaiting_explanation, :blocking ]

      # GET /api/v1/lists/:list_id/tasks
      def index
        tasks = build_tasks_query(@list.tasks.where(parent_task_id: nil).not_deleted)

        # Apply pagination
        page = [ params[:page].to_i, 1 ].max
        per_page = per_page_limit
        offset = (page - 1) * per_page

        paginated_tasks = tasks.limit(per_page).offset(offset)

        render json: {
          tasks: paginated_tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json },
          tombstones: [],
          pagination: {
            page: page,
            per_page: per_page,
            total: tasks.count,
            total_pages: (tasks.count.to_f / per_page).ceil
          }
        }, status: :ok
      end

      # GET /api/v1/tasks - Get all tasks across all lists for current user
      def all_tasks
        tasks = build_tasks_query(
          Task.joins(:list)
              .where(lists: { user_id: current_user.id })
              .where(parent_task_id: nil)
              .not_deleted
        )

        # Apply pagination
        page = [ params[:page].to_i, 1 ].max
        per_page = per_page_limit
        offset = (page - 1) * per_page

        paginated_tasks = tasks.limit(per_page).offset(offset)

        render json: {
          tasks: paginated_tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json },
          tombstones: [],
          pagination: {
            page: page,
            per_page: per_page,
            total: tasks.count,
            total_pages: (tasks.count.to_f / per_page).ceil
          }
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
          return render json: { error: { message: "Bad Request" } }, status: :bad_request
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
            return render json: { error: { message: "You do not have permission to add tasks to this list" } },
                   status: :forbidden
          end
        end

        @task = TaskCreationService.new(@list, current_user, task_params).call
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :created
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Task creation validation failed: #{e.record.errors.full_messages}"
        render json: {
          error: "Validation failed",
          details: e.record.errors.to_hash
        }, status: :unprocessable_entity
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id
      def update
        if @task.update(task_params)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json
        else
          Rails.logger.error "Task update validation failed: #{@task.errors.full_messages}"
          render json: {
            error: {
              message: "Validation failed",
              details: @task.errors.as_json
            }
          }, status: :unprocessable_entity
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
          return render json: {
            error: {
              message: "You do not have permission to modify this task",
              task_id: @task.id,
              user_id: current_user.id,
              list_owner_id: @task.list.user_id
            }
          }, status: :forbidden
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
          return render json: {
            error: {
              message: "You do not have permission to modify this task",
              task_id: @task.id,
              user_id: current_user.id,
              list_owner_id: @task.list.user_id
            }
          }, status: :forbidden
        end

        @task.uncomplete!
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      end

      # POST /api/v1/tasks/:id/reassign
      # PATCH /api/v1/tasks/:id/reassign
      def reassign
        unless @task.list.user_id == current_user.id
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
        end

        uid = params[:assigned_to]
        unless uid.present?
          return render json: { error: { message: "assigned_to parameter is required" } },
                 status: :bad_request
        end

        if Task.column_names.include?("assigned_to_id")
          @task.update!(assigned_to_id: uid)
        elsif Task.column_names.include?("assigned_to")
          @task.update!(assigned_to: uid)
        else
          return render json: { error: { message: "Task does not support assignment" } },
                 status: :unprocessable_entity
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Task reassignment validation failed: #{e.record.errors.full_messages}"
        render json: {
          error: {
            message: "Validation failed",
            details: e.record.errors.as_json
          }
        }, status: :unprocessable_entity
      end

      # POST /api/v1/tasks/:id/submit_explanation
      def submit_explanation
        unless @task.list.user_id == current_user.id
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
        end

        attrs = {}
        if Task.column_names.include?("missed_reason")
          attrs[:missed_reason] = params[:missed_reason].to_s
        end
        if Task.column_names.include?("missed_reason_submitted_at")
          attrs[:missed_reason_submitted_at] = Time.current
        end

        if attrs.empty?
          return render json: { error: { message: "Task does not support missed-explanation fields" } },
                 status: :unprocessable_entity
        end

        if @task.update(attrs)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          render json: {
            error: {
              message: "Validation failed",
              details: @task.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/tasks/:id/toggle_visibility
      def toggle_visibility
        unless @task.list.user_id == current_user.id
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
        end

        visibility = params[:visibility]

        if visibility.present?
          # Handle visibility parameter (for change_visibility-style calls)
          unless Task.visibilities.keys.include?(visibility)
            return render json: { error: { message: "Invalid visibility setting" } },
                   status: :bad_request
          end

          @task.update!(visibility: visibility)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          # Handle coach_id/visible parameters (for toggle_visibility-style calls)
          coach_id = params[:coach_id]
          visible = params[:visible]

          unless coach_id.present?
            return render json: { error: { message: "coach_id parameter is required" } },
                   status: :bad_request
          end

          coach = User.find(coach_id)
          relationship = current_user.relationship_with_coach(coach)

          unless relationship
            return render json: { error: { message: "Not Found" } }, status: :not_found
          end

          if visible
            @task.show_to!(relationship)
          else
            @task.hide_from!(relationship)
          end

          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.error "User not found in toggle_visibility: #{e.message}"
        render json: { error: { message: "User not found" } }, status: :not_found
      end

      # PATCH /api/v1/tasks/:id/change_visibility
      def change_visibility
        visibility = params[:visibility]

        unless %w[visible hidden coaching_only].include?(visibility)
          return render json: { error: { message: "Invalid visibility setting" } },
                 status: :bad_request
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
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
        end

        due_time = parse_iso(params[:due_at])
        if Task.validators_on(:due_at).any? { |v| v.kind == :presence } && due_time.nil?
          return render json: {
            error: {
              message: "Validation failed",
              details: { due_at: [ "is invalid or missing" ] }
            }
          }, status: :unprocessable_entity
        end

        sub_attrs = {
          title: params.require(:title),
          note: params[:note],
          due_at: due_time,
          list_id: @task.list_id,
          creator_id: current_user.id,
          strict_mode: true
        }

        # prefer parent_task_id, fall back to parent_task association if you use that
        if Task.column_names.include?("parent_task_id")
          sub_attrs[:parent_task_id] = @task.id
        end

        sub = Task.new(sub_attrs)

        if sub.save
          render json: TaskSerializer.new(sub, current_user: current_user).as_json.merge(parent_task_id: @task.id),
                 status: :created
        else
          render json: {
            error: {
              message: "Validation failed",
              details: sub.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.error "Missing required parameter in add_subtask: #{e.message}"
        render json: { error: { message: "Title is required" } }, status: :bad_request
      end

      # PATCH /api/v1/tasks/:id/subtasks/:subtask_id
      def update_subtask
        unless @task.list.user_id == current_user.id
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
        end

        if @task.update(task_params)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
        else
          render json: {
            error: {
              message: "Validation failed",
              details: @task.errors.as_json
            }
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id/subtasks/:subtask_id
      def delete_subtask
        unless @task.list.user_id == current_user.id
          return render json: { error: { message: "Forbidden" } }, status: :forbidden
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

        render json: {
          tasks: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
        }
      end

      # GET /api/v1/tasks/overdue
      def overdue
        @tasks = Task.joins(:list)
                     .where(lists: { user_id: current_user.id })
                     .overdue
                     .includes(:creator, :list, :escalation)
                     .order(due_at: :asc)

        render json: {
          tasks: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
        }
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
          @list = List.find(list_id)
          # Check if user has access to this list
          unless @list.can_view?(current_user)
            render json: { error: { message: "List not found" } }, status: :forbidden
            nil
          end
        end
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "List not found: User #{current_user.id} tried to access list #{list_id}"
        render json: { error: { message: "List not found" } }, status: :not_found
      end

      def set_task
        @task = Task.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        Rails.logger.warn "Task not found: User #{current_user.id} tried to access task #{params[:id]}"
        render json: { error: { message: "Task not found" } }, status: :not_found
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
            :list_id, :visibility,
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
              :list_id, :name, :dueDate, :description, :due_date, :visibility,
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
              :list_id, :name, :dueDate, :description, :due_date, :visibility,
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
          render json: { error: { message: "You do not have permission to change task visibility" } },
                 status: :forbidden
        end
      end

      def parse_iso(date_string)
        return nil if date_string.blank?
        Time.parse(date_string)
      rescue ArgumentError
        nil
      end

      def validate_params
        # Validate pagination parameters
        if params[:page].present? && params[:page].to_i < 1
          render json: { error: { message: "Page must be a positive integer" } },
                 status: :bad_request
          return
        end

        if params[:per_page].present? && (params[:per_page].to_i < 1 || params[:per_page].to_i > 100)
          render json: { error: { message: "Per page must be between 1 and 100" } },
                 status: :bad_request
          return
        end

        # Validate status filter
        if params[:status].present? && !%w[pending completed done overdue].include?(params[:status])
          render json: { error: { message: "Invalid status filter" } },
                 status: :bad_request
          nil
        end
      end

      def build_tasks_query(base_query)
        # Apply status filtering
        if params[:status].present?
          case params[:status]
          when "pending"
            base_query = base_query.where(status: "pending")
          when "completed", "done"
            base_query = base_query.where(status: "done")
          when "overdue"
            base_query = base_query.where("due_at < ?", Time.current).where.not(status: "done")
          end
        end

        # Apply list filtering for all_tasks
        if params[:list_id].present?
          base_query = base_query.where(list_id: params[:list_id])
        end

        # Apply sorting - use hash syntax to prevent SQL injection
        sort_by = params[:sort_by] || "created_at"
        sort_order = params[:sort_order] || "desc"

        # Whitelist valid columns and directions
        valid_columns = %w[created_at updated_at due_at title]
        valid_directions = %w[asc desc]

        if valid_columns.include?(sort_by) && valid_directions.include?(sort_order)
          # Use hash syntax instead of string interpolation
          base_query = base_query.order(sort_by.to_sym => sort_order.to_sym)
        else
          base_query = base_query.order(created_at: :desc)
        end

        base_query
      end

      def per_page_limit
        per_page = params[:per_page].to_i
        per_page = 25 if per_page == 0 # Default to 25 if not specified
        per_page.clamp(1, 100)
      end
    end
  end
end
