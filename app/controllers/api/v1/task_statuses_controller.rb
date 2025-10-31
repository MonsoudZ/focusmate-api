# frozen_string_literal: true

module Api
  module V1
    class TaskStatusesController < ApplicationController
      include TaskControllerShared

      # POST /api/v1/tasks/:id/complete
      def complete
        service = TaskCompletionService.new(task: @task, user: current_user)
        service.toggle_completion!(completed: params[:completed])
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue TaskCompletionService::UnauthorizedError => e
        render json: {
          error: {
            message: e.message,
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }
        }, status: :forbidden
      end

      # PATCH /api/v1/tasks/:id/uncomplete
      def uncomplete
        service = TaskCompletionService.new(task: @task, user: current_user)
        service.uncomplete!
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue TaskCompletionService::UnauthorizedError => e
        render json: {
          error: {
            message: e.message,
            task_id: @task.id,
            user_id: current_user.id,
            list_owner_id: @task.list.user_id
          }
        }, status: :forbidden
      end
    end
  end
end
