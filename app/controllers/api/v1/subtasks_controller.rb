# frozen_string_literal: true

module Api
  module V1
    class SubtasksController < BaseController
      before_action :set_parent_task
      before_action :set_subtask, only: [ :show, :update, :destroy, :complete, :reopen ]

      after_action :verify_authorized

      # GET /api/v1/lists/:list_id/tasks/:task_id/subtasks
      def index
        authorize @parent_task, :show?

        subtasks = @parent_task.subtasks.where(deleted_at: nil).order(:position)

        render json: {
          subtasks: subtasks.map { |s| SubtaskSerializer.new(s).as_json }
        }, status: :ok
      end

      # GET /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id
      def show
        authorize @subtask
        render json: { subtask: SubtaskSerializer.new(@subtask).as_json }
      end

      # POST /api/v1/lists/:list_id/tasks/:task_id/subtasks
      def create
        authorize @parent_task, :update?

        subtask = SubtaskCreationService.call!(
          parent_task: @parent_task,
          user: current_user,
          params: subtask_params
        )

        render json: { subtask: SubtaskSerializer.new(subtask).as_json }, status: :created
      end

      # PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id
      def update
        authorize @subtask
        @subtask.update!(subtask_params)
        render json: { subtask: SubtaskSerializer.new(@subtask).as_json }
      end

      # DELETE /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id
      def destroy
        authorize @subtask
        @subtask.soft_delete!
        head :no_content
      end

      # PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id/complete
      def complete
        authorize @subtask, :update?
        @subtask.complete!
        render json: { subtask: SubtaskSerializer.new(@subtask).as_json }
      end

      # PATCH /api/v1/lists/:list_id/tasks/:task_id/subtasks/:id/reopen
      def reopen
        authorize @subtask, :update?
        @subtask.uncomplete!
        render json: { subtask: SubtaskSerializer.new(@subtask).as_json }
      end

      private

      def set_parent_task
        @parent_task = policy_scope(Task).find(params[:task_id])
      end

      def set_subtask
        @subtask = @parent_task.subtasks.where(deleted_at: nil).find(params[:id])
      end

      def subtask_params
        if params[:subtask].present?
          params.require(:subtask).permit(:title, :note, :status, :position)
        else
          params.permit(:title, :note, :status, :position)
        end
      end
    end
  end
end
