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

      # GET /api/v1/today/stats
      def stats
        query = TodayTasksQuery.new(current_user, timezone: current_user.timezone)

        render json: { stats: query.stats }, status: :ok
      end

      # GET /api/v1/today/upcoming
      def upcoming
        days = params.fetch(:days, 7).to_i.clamp(1, 30)
        limit = params.fetch(:limit, 20).to_i.clamp(1, 100)

        query = TodayTasksQuery.new(current_user, timezone: current_user.timezone)
        tasks = query.upcoming(days: days, limit: limit)

        render json: {
          upcoming: serialize_tasks(tasks),
          days: days
        }, status: :ok
      end

      private

      def serialize_tasks(tasks)
        tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json }
      end
    end
  end
end
