# app/controllers/api/v1/tasks_controller.rb
module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_list, only: [:index, :create]
      before_action :set_task, only: [:show, :update, :destroy, :complete, :uncomplete, :reassign, :submit_explanation, :toggle_visibility, :add_subtask, :update_subtask, :delete_subtask, :change_visibility]
      before_action :authorize_task_access, only: [:show]
      before_action :authorize_task_edit, only: [:update, :destroy]
      before_action :authorize_task_visibility_change, only: [:change_visibility]

      # GET /api/v1/lists/:list_id/tasks
      def index
        # Use Pundit policy to filter tasks visible to current user
        @tasks = policy_scope(@list.tasks)
                      .where(parent_task_id: nil) # Don't include subtasks at top level
                      .includes(:creator, :subtasks, :escalation)
                      .order(Arel.sql('
                        CASE 
                          WHEN status = 1 THEN 3
                          WHEN strict_mode = true THEN 0
                          ELSE 2
                        END,
                        due_at ASC NULLS LAST
                      '))
        
        render json: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
      end

      # GET /api/v1/lists/:list_id/tasks/:id
      def show
        render json: TaskSerializer.new(@task, current_user: current_user, include_subtasks: true).as_json
      end

      # POST /api/v1/lists/:list_id/tasks
        def create
          unless @list.can_add_items_by?(current_user)
            # Try to find a list the user can add items to
            fallback_list = current_user.owned_lists.first
            if fallback_list && fallback_list.can_add_items_by?(current_user)
              @list = fallback_list
              Rails.logger.info "Redirected task creation from list #{params[:list_id]} to list #{@list.id} for user #{current_user.id}"
            else
              return render json: { error: 'You do not have permission to add tasks to this list' }, status: :forbidden
            end
          end

        # Normalize incoming params from various clients (iOS uses name/dueDate)
        attrs = task_params.to_h
        
        # Handle iOS-specific parameters (don't pass them to the model)
        if params[:name].present?
          attrs[:title] = params[:name]
        end
        
        if params[:dueDate].present? && attrs[:due_at].blank?
          # iOS sends epoch seconds
          begin
            attrs[:due_at] = Time.at(params[:dueDate].to_i)
          rescue
            # ignore bad format
          end
        end
        
        if params[:due_date].present? && attrs[:due_at].blank?
          # Handle ISO8601 date format
          begin
            attrs[:due_at] = Time.parse(params[:due_date])
          rescue
            # ignore bad format
          end
        end
        
        if params[:description].present?
          attrs[:note] = params[:description]
        end
        
        # Set default values for required fields
        attrs[:strict_mode] = true if attrs[:strict_mode].nil?

        # Remove any iOS-specific parameters that shouldn't go to the model
        attrs.delete(:name)
        attrs.delete(:dueDate)
        attrs.delete(:description)
        attrs.delete(:due_date)  # Remove the raw due_date parameter

        @task = @list.tasks.build(attrs)
        @task.creator = current_user
        
        if @task.save
          # Create subtasks if provided
          if params[:subtasks].present?
            params[:subtasks].each do |subtask_title|
              @task.subtasks.create!(
                list: @list,
                creator: current_user,
                title: subtask_title,
                due_at: @task.due_at,
                priority: @task.priority
              )
            end
          end

          # Notify client if coach created it
          NotificationService.new_item_assigned(@task) if @task.created_by_coach?
          
          # Set up geofencing if location-based
          # if @task.location_based?
          #   GeofencingService.setup_geofence(@task)
          # end
          
          render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :created
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/lists/:list_id/tasks/:id
      def update
        if @task.update(task_params)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
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
            error: 'Unauthorized',
            message: 'You do not have permission to modify this task',
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }, status: :forbidden
          return
        end
        
        # Handle both completion states based on the completed parameter
        if params[:completed] == false || params[:completed] == 'false'
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
            error: 'Unauthorized',
            message: 'You do not have permission to modify this task',
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
        unless can_access_task?(@task)
          render json: { 
            error: 'Unauthorized',
            message: 'You do not have permission to reassign this task',
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }, status: :forbidden
          return
        end

        # Handle reassignment to different list
        new_list_id = params[:list_id]
        if new_list_id.present?
          new_list = List.find(new_list_id)
          
          unless new_list.can_add_items?(current_user)
            return render json: { error: 'Cannot reassign to that list' }, status: :forbidden
          end
          
          @task.update!(list_id: new_list_id)
        end

        # Handle due date update
        if params[:due_at].present?
          begin
            new_due_at = Time.parse(params[:due_at])
            @task.update!(due_at: new_due_at)
          rescue ArgumentError
            return render json: { error: 'Invalid due_at format' }, status: :unprocessable_entity
          end
        end

        # Create task event for reassignment
        @task.create_task_event(
          user: current_user,
          kind: :reassigned,
          reason: params[:reason],
          occurred_at: Time.current
        )
        
        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # POST /api/v1/tasks/:id/submit_explanation
      def submit_explanation
        unless @task.list.owner == current_user
          return render json: { error: 'Only list owner can submit explanations' }, status: :forbidden
        end

        unless @task.requires_explanation?
          return render json: { error: 'This task does not require an explanation' }, status: :unprocessable_entity
        end

        if @task.submit_explanation!(params[:reason], current_user)
          render json: TaskSerializer.new(@task, current_user: current_user).as_json
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/tasks/:id/toggle_visibility
      def toggle_visibility
        unless @task.list.owner == current_user
          return render json: { error: 'Only list owner can control visibility' }, status: :forbidden
        end

        coach_id = params[:coach_id]
        visible = params[:visible]

        coach = User.find(coach_id)
        relationship = current_user.relationship_with_coach(coach)

        unless relationship
          return render json: { error: 'No coaching relationship found' }, status: :not_found
        end

        if visible
          @task.show_to!(relationship)
        else
          @task.hide_from!(relationship)
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # PATCH /api/v1/tasks/:id/change_visibility
      def change_visibility
        visibility = params[:visibility]
        
        unless %w[visible hidden coaching_only].include?(visibility)
          return render json: { error: 'Invalid visibility setting' }, status: :unprocessable_entity
        end

        case visibility
        when 'visible'
          @task.make_visible!
        when 'hidden'
          @task.make_hidden!
        when 'coaching_only'
          @task.make_coaching_only!
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json
      end

      # POST /api/v1/tasks/:id/add_subtask
      def add_subtask
        unless @task.editable_by?(current_user)
          return render json: { error: 'Cannot add subtasks to this task' }, status: :forbidden
        end

        subtask = @task.subtasks.build(
          list: @task.list,
          creator: current_user,
          title: params[:title],
          note: params[:description] || params[:note],
          due_at: params[:due_at] || @task.due_at,
          priority: @task.priority
        )

        if subtask.save
          render json: TaskSerializer.new(subtask, current_user: current_user).as_json, status: :created
        else
          render json: { errors: subtask.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/tasks/:id/subtasks/:subtask_id
      def update_subtask
        subtask = @task.subtasks.find(params[:subtask_id])
        
        unless subtask.editable_by?(current_user)
          return render json: { error: 'Cannot edit this subtask' }, status: :forbidden
        end

        if subtask.update(task_params)
          render json: TaskSerializer.new(subtask, current_user: current_user).as_json
        else
          render json: { errors: subtask.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id/subtasks/:subtask_id
      def delete_subtask
        subtask = @task.subtasks.find(params[:subtask_id])
        
        unless subtask.deletable_by?(current_user)
          return render json: { error: 'Cannot delete this subtask' }, status: :forbidden
        end

        subtask.destroy
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
                     .where(lists: { owner_id: current_user.id })
                     .awaiting_explanation
                     .includes(:creator, :list)
        
        render json: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
      end

      # GET /api/v1/tasks/overdue
      def overdue
        @tasks = Task.joins(:list)
                     .where(lists: { owner_id: current_user.id })
                     .overdue
                     .includes(:creator, :list, :escalation)
                     .order(due_at: :asc)
        
        render json: @tasks.map { |task| TaskSerializer.new(task, current_user: current_user).as_json }
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
        end
      end

      def set_task
        if params[:list_id]
          @task = Task.find(params[:id])
        else
          @task = Task.find(params[:id])
        end
      end

      def authorize_task_access
        unless @task.visible_to?(current_user)
          render json: { error: 'Task not found' }, status: :not_found
        end
      end

      def authorize_task_edit
        unless @task.editable_by?(current_user)
          render json: { error: 'You can only edit tasks you created' }, status: :forbidden
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
          # Handle direct params from iOS app
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
          render json: { error: 'You do not have permission to change task visibility' }, status: :forbidden
        end
      end
    end
  end
end