module Api
  module V1
    class DashboardController < ApplicationController
      # GET /api/v1/dashboard
      def show
        if current_user.client?
          render json: client_dashboard
        else
          render json: coach_dashboard
        end
      end

      # GET /api/v1/dashboard/stats
      def stats
        if current_user.client?
          render json: client_stats
        else
          render json: coach_stats
        end
      end

      private

      def client_dashboard
        {
          blocking_tasks_count: current_user.owned_lists.joins(tasks: :escalation)
                                            .where(item_escalations: { blocking_app: true }).count,
          overdue_tasks_count: current_user.overdue_tasks.count,
          awaiting_explanation_count: current_user.tasks_requiring_explanation.count,
          coaches_count: current_user.coaches.count,
          completion_rate_this_week: calculate_completion_rate(current_user, 1.week.ago),
          recent_activity: recent_activity_summary,
          upcoming_deadlines: upcoming_deadlines_summary
        }
      end

      def coach_dashboard
        {
          clients_count: current_user.clients.count,
          total_overdue_tasks: current_user.clients.joins(:created_tasks)
                                                   .where(tasks: { status: :pending })
                                                   .where("tasks.due_at < ?", Time.current).count,
          pending_explanations: current_user.clients.joins(:created_tasks)
                                                   .where(tasks: { requires_explanation_if_missed: true })
                                                   .where(tasks: { status: :pending })
                                                   .where("tasks.due_at < ?", Time.current).count,
          active_relationships: current_user.coaching_relationships_as_coach.active.count,
          recent_client_activity: recent_client_activity_summary
        }
      end

      def client_stats
        tasks = Task.joins(:list).where(lists: { user_id: current_user.id })

        {
          total_tasks: tasks.count,
          completed_tasks: tasks.complete.count,
          overdue_tasks: tasks.overdue.count,
          completion_rate: tasks.any? ? (tasks.complete.count.to_f / tasks.count * 100).round(1) : 0,
          average_completion_time: calculate_average_completion_time(current_user),
          tasks_by_priority: {
            urgent: tasks.where(priority: 3).count,
            high: tasks.where(priority: 2).count,
            medium: tasks.where(priority: 1).count,
            low: tasks.where(priority: 0).count
          }
        }
      end

      def coach_stats
        clients = current_user.clients

        {
          total_clients: clients.count,
          active_clients: current_user.coaching_relationships_as_coach.active.count,
          total_tasks_across_clients: Task.joins(:list)
                                          .where(lists: { user_id: clients.pluck(:id) }).count,
          completed_tasks_across_clients: Task.joins(:list)
                                              .where(lists: { user_id: clients.pluck(:id) })
                                              .where(status: :done).count,
          average_client_completion_rate: calculate_average_client_completion_rate,
          client_performance_summary: client_performance_summary
        }
      end

      def calculate_completion_rate(user, since)
        tasks = Task.joins(:list)
                    .where(lists: { user_id: user.id })
                    .where("tasks.created_at >= ?", since)

        return 0 if tasks.none?

        (tasks.complete.count.to_f / tasks.count * 100).round(1)
      end

      def calculate_average_completion_time(user)
        tasks = Task.joins(:list)
                    .where(lists: { user_id: user.id })
                    .where.not(completed_at: nil)
                    .where.not(due_at: nil)

        return 0 if tasks.none?

        total_diff = tasks.sum { |t| (t.completed_at - t.due_at).abs }
        (total_diff / tasks.count / 3600).round(1) # Convert to hours
      end

      def recent_activity_summary
        # Get recent task events for the user
        recent_events = TaskEvent.joins(:task)
                                 .where(tasks: { list: current_user.owned_lists })
                                 .where("task_events.created_at >= ?", 1.week.ago)
                                 .order(created_at: :desc)
                                 .limit(5)

        recent_events.map do |event|
          {
            id: event.id,
            task_title: event.task.title,
            action: event.kind,
            reason: event.reason,
            occurred_at: event.occurred_at
          }
        end
      end

      def upcoming_deadlines_summary
        # Get tasks due in the next 7 days
        upcoming_tasks = Task.joins(:list)
                            .where(lists: { user_id: current_user.id })
                            .where(status: :pending)
                            .where("tasks.due_at BETWEEN ? AND ?", Time.current, 1.week.from_now)
                            .order(:due_at)
                            .limit(5)

        upcoming_tasks.map do |task|
          {
            id: task.id,
            title: task.title,
            due_at: task.due_at,
            list_name: task.list.name,
            days_until_due: ((task.due_at - Time.current) / 1.day).round(1)
          }
        end
      end

      def recent_client_activity_summary
        # Get recent activity across all clients
        recent_events = TaskEvent.joins(:task)
                                 .where(tasks: { list: current_user.clients.joins(:owned_lists).select("lists.id") })
                                 .where("task_events.created_at >= ?", 1.week.ago)
                                 .order(created_at: :desc)
                                 .limit(10)

        recent_events.map do |event|
          {
            id: event.id,
            client_name: event.task.list.owner.name,
            task_title: event.task.title,
            action: event.kind,
            occurred_at: event.occurred_at
          }
        end
      end

      def calculate_average_client_completion_rate
        clients = current_user.clients
        return 0 if clients.empty?

        total_completion_rate = clients.sum do |client|
          tasks = Task.joins(:list).where(lists: { user_id: client.id })
          next 0 if tasks.empty?

          (tasks.where(status: :done).count.to_f / tasks.count * 100).round(1)
        end

        (total_completion_rate / clients.count).round(1)
      end

      def client_performance_summary
        current_user.clients.map do |client|
          tasks = Task.joins(:list).where(lists: { user_id: client.id })

          {
            client_id: client.id,
            client_name: client.name,
            total_tasks: tasks.count,
            completed_tasks: tasks.where(status: :done).count,
            overdue_tasks: tasks.where(status: :pending)
                                .where("tasks.due_at < ?", Time.current).count,
            completion_rate: tasks.any? ? (tasks.where(status: :done).count.to_f / tasks.count * 100).round(1) : 0
          }
        end
      end
    end
  end
end
