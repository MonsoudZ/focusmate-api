# frozen_string_literal: true

module Api
  module V1
    class TaskVisibilityController < ApplicationController
      include TaskControllerShared

      before_action :authorize_task_visibility_change, only: [ :change ]

      # PATCH /api/v1/tasks/:id/toggle_visibility
      def toggle
        service = TaskVisibilityService.new(task: @task, user: current_user)
        visibility = params[:visibility]

        if visibility.present?
          # Handle visibility parameter (for change_visibility-style calls)
          service.change_visibility!(visibility: visibility)
        else
          # Handle coach_id/visible parameters (for toggle_visibility-style calls)
          coach_id = params[:coach_id]
          visible = params[:visible]

          unless coach_id.present?
            return render json: { error: { message: "coach_id parameter is required" } },
                   status: :bad_request
          end

          service.toggle_for_coach!(coach_id: coach_id, visible: visible)
        end

        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue TaskVisibilityService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue TaskVisibilityService::ValidationError => e
        render json: { error: { message: e.message } }, status: :bad_request
      rescue TaskVisibilityService::NotFoundError => e
        Rails.logger.error "Not found in toggle_visibility: #{e.message}"
        render json: { error: { message: e.message } }, status: :not_found
      end

      # PATCH /api/v1/tasks/:id/change_visibility
      def change
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

      # POST /api/v1/tasks/:id/submit_explanation
      def submit_explanation
        service = TaskVisibilityService.new(task: @task, user: current_user)
        service.submit_explanation!(missed_reason: params[:missed_reason])
        render json: TaskSerializer.new(@task, current_user: current_user).as_json, status: :ok
      rescue TaskVisibilityService::UnauthorizedError => e
        render json: { error: { message: e.message } }, status: :forbidden
      rescue TaskVisibilityService::ValidationError => e
        render json: { error: { message: e.message } }, status: :unprocessable_content
      end

      private

      def authorize_task_visibility_change
        unless @task.can_change_visibility?(current_user)
          render json: { error: { message: "You do not have permission to change task visibility" } },
                 status: :forbidden
        end
      end
    end
  end
end
