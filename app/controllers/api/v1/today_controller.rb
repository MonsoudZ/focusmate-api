# frozen_string_literal: true

module Api
  module V1
    class TodayController < BaseController
      include EditableLists
      # Today endpoint is inherently user-scoped (current_user only)
      skip_after_action :verify_authorized

      MAX_OVERDUE = 50

      # GET /api/v1/today
      def index
        query = TodayTasksQuery.new(current_user, timezone: resolve_timezone)
        data = query.fetch_all  # Single call, no duplicate queries
        ids = editable_list_ids

        render json: {
          overdue: serialize_tasks(data[:overdue].first(MAX_OVERDUE), editable_list_ids: ids),
          has_more_overdue: data[:overdue].size > MAX_OVERDUE,
          due_today: serialize_tasks(data[:due_today], editable_list_ids: ids),
          completed_today: serialize_tasks(data[:completed_today], editable_list_ids: ids),
          stats: data[:stats]
        }, status: :ok
      end

      private

      def resolve_timezone
        param_tz = params[:timezone].presence
        return current_user.timezone if param_tz.nil?
        return param_tz if ActiveSupport::TimeZone[param_tz]

        Rails.logger.warn(
          event: "today_invalid_timezone_param",
          user_id: current_user.id,
          timezone: param_tz
        )
        current_user.timezone
      end

      def serialize_tasks(tasks, editable_list_ids:)
        tasks.map do |task|
          TaskSerializer.new(task, current_user: current_user, editable_list_ids: editable_list_ids).as_json
        end
      end
    end
  end
end
