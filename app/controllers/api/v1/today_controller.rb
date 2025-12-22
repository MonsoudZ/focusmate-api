# frozen_string_literal: true

module Api
  module V1
    class TodayController < BaseController
      # GET /api/v1/today
      def index
        beginning_of_day = Time.current.beginning_of_day
        end_of_day = Time.current.end_of_day

        # Get all user's tasks (from owned lists)
        base_tasks = Task.joins(:list)
                        .where(lists: { user_id: current_user.id })
                        .where(parent_task_id: nil)
                        .not_deleted

        overdue_tasks = base_tasks
                          .where("due_at < ?", Time.current)
                          .where.not(status: "done")
                          .order(due_at: :asc)

        due_today_tasks = base_tasks
                            .where(due_at: beginning_of_day..end_of_day)
                            .where.not(status: "done")
                            .order(due_at: :asc)

        completed_today_tasks = base_tasks
                                  .where(completed_at: beginning_of_day..end_of_day)
                                  .where(status: "done")
                                  .order(completed_at: :desc)
                                  .limit(10)

        render json: {
          overdue: overdue_tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json },
          due_today: due_today_tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json },
          completed_today: completed_today_tasks.map { |t| TaskSerializer.new(t, current_user: current_user).as_json },
          stats: {
            overdue_count: overdue_tasks.count,
            due_today_count: due_today_tasks.count,
            completed_today_count: completed_today_tasks.count
          }
        }, status: :ok
      end
    end
  end
end
