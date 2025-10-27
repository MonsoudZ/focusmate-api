# frozen_string_literal: true

class DashboardDataService
  def initialize(user:)
    @user = user
  end

  def call
    if @user.client?
      client_dashboard
    else
      coach_dashboard
    end
  end

  def stats
    if @user.client?
      client_stats
    else
      coach_stats
    end
  end

  private

  def client_dashboard
    # Cache dashboard data for 5 minutes
    cache_key = "client_dashboard_#{@user.id}_#{@user.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: ConfigurationHelper.cache_expiry) do
      {
        blocking_tasks_count: @user.owned_lists.joins(tasks: :escalation)
                                    .where(item_escalations: { blocking_app: true }).count,
        overdue_tasks_count: @user.overdue_tasks.count,
        awaiting_explanation_count: @user.tasks_requiring_explanation.count,
        coaches_count: @user.coaches.count,
        completion_rate_this_week: calculate_completion_rate(@user, ConfigurationHelper.recent_activity_period.ago),
        recent_activity: recent_activity_summary,
        upcoming_deadlines: upcoming_deadlines_summary
      }
    end
  end

  def coach_dashboard
    # Cache dashboard data for 5 minutes
    cache_key = "coach_dashboard_#{@user.id}_#{@user.updated_at.to_i}"

    Rails.cache.fetch(cache_key, expires_in: ConfigurationHelper.cache_expiry) do
      {
        clients_count: @user.clients.count,
        total_overdue_tasks: @user.clients.joins(:created_tasks)
                                         .where(tasks: { status: :pending })
                                         .where("tasks.due_at < ?", Time.current).count,
        pending_explanations: @user.clients.joins(:created_tasks)
                                         .where(tasks: { requires_explanation_if_missed: true })
                                         .where(tasks: { status: :pending })
                                         .where("tasks.due_at < ?", Time.current).count,
        active_relationships: @user.coaching_relationships_as_coach.active.count,
        recent_client_activity: recent_client_activity_summary
      }
    end
  end

  def client_stats
    tasks = Task.joins(:list).where(lists: { user_id: @user.id })

    {
      total_tasks: tasks.count,
      completed_tasks: tasks.where(status: :done).count,
      overdue_tasks: tasks.overdue.count,
      completion_rate: tasks.any? ? (tasks.where(status: :done).count.to_f / tasks.count * 100).round(1) : 0,
      average_completion_time: calculate_average_completion_time(@user),
      tasks_by_priority: {
        urgent: 0,
        high: 0,
        medium: 0,
        low: 0
      }
    }
  end

  def coach_stats
    clients = @user.clients

    {
      total_clients: clients.count,
      active_clients: @user.coaching_relationships_as_coach.active.count,
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

    (tasks.where(status: :done).count.to_f / tasks.count * 100).round(1)
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
    # Get recent task events for the user with proper includes to avoid N+1
    recent_events = TaskEvent.includes(:task)
                             .joins(:task)
                             .where(tasks: { list: @user.owned_lists })
                             .where("task_events.created_at >= ?", ConfigurationHelper.recent_activity_period.ago)
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
                        .where(lists: { user_id: @user.id })
                        .where(status: :pending)
                        .where("tasks.due_at BETWEEN ? AND ?", Time.current, ConfigurationHelper.upcoming_deadlines_period.from_now)
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
    # Get recent activity across all clients with proper includes to avoid N+1
    recent_events = TaskEvent.includes(:task, task: { list: :owner })
                             .joins(:task)
                             .where(tasks: { list: @user.clients.joins(:owned_lists).select("lists.id") })
                             .where("task_events.created_at >= ?", ConfigurationHelper.recent_activity_period.ago)
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
    clients = @user.clients
    return 0 if clients.empty?

    # Optimize with single query instead of N+1
    client_ids = clients.pluck(:id)
    task_stats = Task.joins(:list)
                     .where(lists: { user_id: client_ids })
                     .group("lists.user_id")
                     .select("lists.user_id, COUNT(*) as total_tasks, SUM(CASE WHEN tasks.status = 1 THEN 1 ELSE 0 END) as completed_tasks")

    stats_by_client = task_stats.index_by(&:user_id)

    total_completion_rate = clients.sum do |client|
      stats = stats_by_client[client.id]
      next 0 unless stats && stats.total_tasks.to_i > 0

      (stats.completed_tasks.to_f / stats.total_tasks.to_i * 100).round(1)
    end

    (total_completion_rate / clients.count).round(1)
  end

  def client_performance_summary
    # Optimize with single query instead of N+1
    clients = @user.clients
    client_ids = clients.pluck(:id)

    # Single query to get all task statistics
    task_stats = Task.joins(:list)
                     .where(lists: { user_id: client_ids })
                     .group("lists.user_id")
                     .select('lists.user_id,
                              COUNT(*) as total_tasks,
                              SUM(CASE WHEN tasks.status = 1 THEN 1 ELSE 0 END) as completed_tasks,
                              SUM(CASE WHEN tasks.status = 0 AND tasks.due_at < NOW() THEN 1 ELSE 0 END) as overdue_tasks')

    stats_by_client = task_stats.index_by(&:user_id)

    clients.map do |client|
      stats = stats_by_client[client.id]

      {
        client_id: client.id,
        client_name: client.name,
        total_tasks: stats&.total_tasks || 0,
        completed_tasks: stats&.completed_tasks || 0,
        overdue_tasks: stats&.overdue_tasks || 0,
        completion_rate: (stats && stats.total_tasks.to_i > 0) ? (stats.completed_tasks.to_f / stats.total_tasks.to_i * 100).round(1) : 0
      }
    end
  end
end
