# frozen_string_literal: true

module Api
  module V1
    class TaskSubtasksController < ApplicationController
      include TaskControllerShared

      # POST /api/v1/tasks/:id/subtasks
      def create
        title = params[:title]
        unless title.present?
          return render json: { error: { message: "Title is required" } }, status: :bad_request
        end

        service = SubtaskManagementService.new(parent_task: @task, user: current_user)
        due_time = parse_iso(params[:due_at])
        subtask = service.create_subtask!(
          title: title,
          note: params[:note],
          due_at: due_time
        )

        render json: TaskSerializer.new(subtask, current_user: current_user).as_json.merge(parent_task_id: @task.id),
               status: :created
      rescue SubtaskManagementService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue SubtaskManagementService::ValidationError => e
        Rails.logger.error "Subtask creation validation failed: #{e.message}"
        render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
      end

      # PATCH /api/v1/tasks/:id/subtasks/:subtask_id
      def update
        # Note: @task in this context is the subtask being updated
        # We need to find the parent task to use the service
        parent_task = @task.parent_task || Task.find_by(id: @task.parent_task_id)

        service = SubtaskManagementService.new(parent_task: parent_task, user: current_user)
        service.update_subtask!(subtask: @task, attributes: task_params)
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue SubtaskManagementService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue SubtaskManagementService::ValidationError => e
        render json: { error: { message: e.message, details: e.details } }, status: :unprocessable_content
      end

      # DELETE /api/v1/tasks/:id/subtasks/:subtask_id
      def destroy
        # Note: @task in this context is the subtask being deleted
        parent_task = @task.parent_task || Task.find_by(id: @task.parent_task_id)

        service = SubtaskManagementService.new(parent_task: parent_task, user: current_user)
        service.delete_subtask!(subtask: @task)
        head :no_content
      rescue SubtaskManagementService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      end

      private

      def task_params
        # Handle both nested task params and direct params
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
  end
end
