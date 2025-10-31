# frozen_string_literal: true

module Api
  module V1
    class TaskQueriesController < ApplicationController
      before_action :authenticate_user!
      before_action :validate_params

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
    end
  end
end
