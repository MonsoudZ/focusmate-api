# frozen_string_literal: true

module Api
  module V1
    class TodayController < BaseController
      # Today endpoint doesn't use Pundit - it's inherently user-scoped
      skip_after_action :verify_authorized, raise: false
      skip_after_action :verify_policy_scoped, raise: false

      # GET /api/v1/today
      def index
        query = TodayTasksQuery.new(current_user, timezone: current_user.timezone)
        data = query.all_for_today
        stats = query.stats

        render json: {
          overdue: serialize_tasks(data[:overdue]),
          due_today: serialize_tasks(data[:due_today]),
          completed_today: serialize_tasks(data[:completed_today]),
          stats: stats
        }, status: :ok
      end

      private

      def serialize_tasks(tasks)
        tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json }
      end
    end
  end
end
