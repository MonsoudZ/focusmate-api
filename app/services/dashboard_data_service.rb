# frozen_string_literal: true

require "digest"

class DashboardDataService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(details: {}); @details = details; super("validation_error"); end
  end

  class TooExpensiveError < StandardError; end

  def initialize(user:, window: nil, sections: [])
    @user = user
    @window = window || { from: 30.days.ago, to: Time.current }
    @sections = sections
  end

  def call
    if @user.role == "coach"
      coach_dashboard_data
    else
      user_dashboard_data
    end
  end

  def user_dashboard_data
    {
      inbox_count: inbox_count,
      overdue_count: overdue_count,
      completion_rate: completion_rate,
      recent_tasks: recent_tasks,
      blocking_tasks_count: blocking_tasks_count,
      overdue_tasks_count: overdue_count,
      awaiting_explanation_count: awaiting_explanation_count,
      coaches_count: coaches_count,
      completion_rate_this_week: completion_rate_this_week,
      recent_activity: recent_activity,
      upcoming_deadlines: upcoming_deadlines,
      digest: generate_digest,
      last_modified: last_modified
    }
  end

  def coach_dashboard_data
    {
      clients_count: clients_count,
      total_overdue_tasks: total_overdue_tasks,
      pending_explanations: pending_client_explanations,
      active_relationships: active_relationships_count,
      recent_client_activity: recent_client_activity,
      digest: generate_digest,
      last_modified: last_modified
    }
  end

  def stats(group_by: "day", limit: 30)
    if @user.role == "coach"
      coach_stats(group_by, limit)
    else
      user_stats(group_by, limit)
    end
  end

  def user_stats(group_by, limit)
    {
      total_tasks: total_tasks,
      completed_tasks: completed_tasks,
      overdue_tasks: overdue_count,
      completion_rate: completion_rate,
      average_completion_time: average_completion_time,
      tasks_by_priority: tasks_by_priority,
      series: build_series(group_by, limit),
      digest: generate_digest,
      last_modified: last_modified
    }
  end

  def coach_stats(group_by, limit)
    {
      total_clients: clients_count,
      active_clients: active_relationships_count,
      total_tasks_across_clients: total_client_tasks,
      completed_tasks_across_clients: completed_client_tasks,
      average_client_completion_rate: average_client_completion_rate,
      client_performance_summary: client_performance_summary,
      series: build_series(group_by, limit),
      digest: generate_digest,
      last_modified: last_modified
    }
  end

  private

  def inbox_count
    user_tasks.where(completed_at: nil).count
  end

  def overdue_count
    user_tasks.overdue.count
  end

  def total_tasks
    user_tasks.count
  end

  def completed_tasks
    user_tasks.completed.count
  end

  def completion_rate
    total = total_tasks
    return 0.0 if total.zero?
    (completed_tasks.to_f / total * 100).round(1)
  end

  def recent_tasks
    user_tasks.order(created_at: :desc).limit(5).pluck(:title, :status)
  end

  def user_tasks
    Task.joins(:list).where(lists: { user_id: @user.id })
  end

  def build_series(group_by, limit)
    case group_by
    when "day"
      build_daily_series(limit)
    when "week"
      build_weekly_series(limit)
    when "month"
      build_monthly_series(limit)
    else
      build_daily_series(limit)
    end
  end

  def build_daily_series(limit)
    completed_tasks = user_tasks.completed
                          .where(completed_at: @window[:from]..@window[:to])
                          .group("DATE(completed_at)")
                          .count

    (@window[:from].to_date..@window[:to].to_date)
      .last(limit)
      .map do |date|
        {
          period: date.iso8601,
          completed: completed_tasks[date] || 0
        }
      end
  end

  def build_weekly_series(limit)
    completed_tasks = user_tasks.completed
                          .where(completed_at: @window[:from]..@window[:to])
                          .group("DATE_TRUNC('week', completed_at)")
                          .count

    weeks = []
    current_week = @window[:from].beginning_of_week
    end_week = @window[:to].end_of_week

    while current_week <= end_week && weeks.length < limit
      week_start = current_week.to_date
      week_end = (current_week + 6.days).to_date

      weeks << {
        period: "#{week_start.iso8601}/#{week_end.iso8601}",
        completed: completed_tasks[current_week] || 0
      }

      current_week += 1.week
    end

    weeks
  end

  def build_monthly_series(limit)
    completed_tasks = user_tasks.completed
                          .where(completed_at: @window[:from]..@window[:to])
                          .group("DATE_TRUNC('month', completed_at)")
                          .count

    months = []
    current_month = @window[:from].beginning_of_month
    end_month = @window[:to].end_of_month

    while current_month <= end_month && months.length < limit
      months << {
        period: current_month.strftime("%Y-%m"),
        completed: completed_tasks[current_month] || 0
      }

      current_month = current_month.next_month
    end

    months
  end

  # User dashboard methods
  def blocking_tasks_count
    ItemEscalation.joins(task: { list: :user })
                  .where(lists: { user_id: @user.id })
                  .where(escalation_level: "blocking", blocking_app: true)
                  .count
  end

  def awaiting_explanation_count
    user_tasks.where(requires_explanation_if_missed: true)
              .where("due_at < ?", Time.current)
              .where(status: :pending)
              .count
  end

  def coaches_count
    CoachingRelationship.where(client_id: @user.id, status: "active").count
  end

  def completion_rate_this_week
    week_start = Time.current.beginning_of_week
    week_tasks = user_tasks.where("tasks.created_at >= ?", week_start)
    week_total = week_tasks.count
    return 0.0 if week_total.zero?

    week_completed = week_tasks.completed.count
    (week_completed.to_f / week_total * 100).round(1)
  end

  def recent_activity
    TaskEvent.joins(task: { list: :user })
             .includes(task: :list)
             .where(lists: { user_id: @user.id })
             .order(created_at: :desc)
             .limit(10)
             .map do |event|
      {
        id: event.id,
        task_title: event.task.title,
        action: event.event_type,
        occurred_at: event.created_at.iso8601
      }
    end
  end

  def upcoming_deadlines
    user_tasks.includes(:list)
              .where(status: :pending)
              .where("due_at > ?", Time.current)
              .order(due_at: :asc)
              .limit(10)
              .map do |task|
      {
        id: task.id,
        title: task.title,
        due_at: task.due_at.iso8601,
        list_name: task.list.name,
        days_until_due: ((task.due_at - Time.current) / 1.day).round(1)
      }
    end
  end

  # Coach dashboard methods
  def active_client_ids
    @active_client_ids ||= CoachingRelationship.where(coach_id: @user.id, status: "active").pluck(:client_id)
  end

  def clients_count
    active_client_ids.count
  end

  def total_overdue_tasks
    Task.joins(:list).where(lists: { user_id: active_client_ids }).overdue.count
  end

  def pending_client_explanations
    Task.joins(:list)
        .where(lists: { user_id: active_client_ids })
        .where(requires_explanation_if_missed: true)
        .where("due_at < ?", Time.current)
        .where(status: :pending)
        .count
  end

  def active_relationships_count
    active_client_ids.count
  end

  def recent_client_activity
    TaskEvent.joins(task: { list: :user })
             .includes(task: { list: :user })
             .where(lists: { user_id: active_client_ids })
             .order(created_at: :desc)
             .limit(10)
             .map do |event|
      {
        id: event.id,
        client_name: event.task.list.user.name,
        task_title: event.task.title,
        action: event.event_type,
        occurred_at: event.created_at.iso8601
      }
    end
  end

  # Stats methods
  def average_completion_time
    completed = user_tasks.completed.where.not(completed_at: nil)
    return 0.0 if completed.count.zero?

    total_time = completed.sum("EXTRACT(EPOCH FROM (tasks.completed_at - tasks.created_at))")
    (total_time.to_f / completed.count / 3600).round(1) # Convert to hours
  end

  def tasks_by_priority
    # Priority field doesn't exist in current schema, return placeholder counts
    # Tasks can be categorized by due date proximity instead
    now = Time.current
    urgent = user_tasks.where("due_at < ?", now + 1.day).count
    high = user_tasks.where("due_at >= ? AND due_at < ?", now + 1.day, now + 3.days).count
    medium = user_tasks.where("due_at >= ? AND due_at < ?", now + 3.days, now + 7.days).count
    low = user_tasks.where("due_at >= ?", now + 7.days).count

    {
      urgent: urgent,
      high: high,
      medium: medium,
      low: low
    }
  end

  def total_client_tasks
    Task.joins(:list).where(lists: { user_id: active_client_ids }).count
  end

  def completed_client_tasks
    Task.joins(:list).where(lists: { user_id: active_client_ids }).completed.count
  end

  def average_client_completion_rate
    return 0.0 if active_client_ids.empty?

    # Get all task counts in a single query using GROUP BY
    # status enum: pending: 0, in_progress: 1, done: 2, deleted: 3
    # Use pluck to avoid instantiating Task objects
    task_counts = Task.joins(:list)
                      .where(lists: { user_id: active_client_ids })
                      .group("lists.user_id")
                      .pluck(Arel.sql("lists.user_id, COUNT(*) as total_count, SUM(CASE WHEN tasks.status = 2 THEN 1 ELSE 0 END) as completed_count"))

    rates = task_counts.map do |user_id, total, completed|
      total = total.to_i
      next 0.0 if total.zero?
      completed = completed.to_i
      (completed.to_f / total * 100)
    end

    return 0.0 if rates.empty?
    (rates.sum / rates.length).round(1)
  end

  def client_performance_summary
    # Get all task counts in a single query
    # status enum: pending: 0, in_progress: 1, done: 2, deleted: 3
    # Use pluck to avoid instantiating Task objects
    task_counts_array = Task.joins(:list)
                            .where(lists: { user_id: active_client_ids })
                            .group("lists.user_id")
                            .pluck(Arel.sql("lists.user_id, COUNT(*) as total_count, SUM(CASE WHEN tasks.status = 2 THEN 1 ELSE 0 END) as completed_count"))

    # Convert to hash for lookup
    task_counts = task_counts_array.to_h { |user_id, total, completed| [ user_id, { total: total.to_i, completed: completed.to_i } ] }

    # Eager load users and build summary
    User.where(id: active_client_ids).map do |client|
      counts = task_counts[client.id] || { total: 0, completed: 0 }
      total = counts[:total]
      completed = counts[:completed]
      completion_rate = total.zero? ? 0.0 : (completed.to_f / total * 100).round(1)

      {
        client_id: client.id,
        client_name: client.name,
        total_tasks: total,
        completed_tasks: completed,
        completion_rate: completion_rate
      }
    end
  end

  def generate_digest
    Digest::SHA1.hexdigest([ @user.id, @window[:from].to_i, @window[:to].to_i ].join(":"))
  end

  def last_modified
    user_tasks.maximum(:updated_at) || Time.current
  end
end
