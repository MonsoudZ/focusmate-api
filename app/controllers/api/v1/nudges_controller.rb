# frozen_string_literal: true

module Api
  module V1
    class NudgesController < BaseController
      before_action :set_task

      def create
        authorize @task, :nudge?

        # Find the task owner
        task_owner = @task.user || @task.list.user

        # Don't nudge yourself
        if task_owner.id == current_user.id
          render json: { error: "You cannot nudge yourself" }, status: :unprocessable_entity
          return
        end

        # Send push notification
        PushNotifications::Sender.send_nudge(
          from_user: current_user,
          to_user: task_owner,
          task: @task
        )

        # Record the nudge
        Nudge.create!(
          task: @task,
          from_user: current_user,
          to_user: task_owner
        )

        render json: { message: "Nudge sent" }, status: :ok
      end

      private

      def set_task
        @task = Task.find(params[:task_id])
      end
    end
  end
end
