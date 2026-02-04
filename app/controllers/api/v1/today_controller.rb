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
        data = query.fetch_all  # Single call, no duplicate queries
        ids = editable_list_ids

        render json: {
          overdue: serialize_tasks(data[:overdue], editable_list_ids: ids),
          due_today: serialize_tasks(data[:due_today], editable_list_ids: ids),
          completed_today: serialize_tasks(data[:completed_today], editable_list_ids: ids),
          stats: data[:stats]
        }, status: :ok
      end

      private

      def serialize_tasks(tasks, editable_list_ids:)
        tasks.map do |task|
          TaskSerializer.new(task, current_user: current_user, editable_list_ids: editable_list_ids).as_json
        end
      end

      def editable_list_ids
        @editable_list_ids ||= Membership.where(user_id: current_user.id, role: "editor").pluck(:list_id)
      end
    end
  end
end
