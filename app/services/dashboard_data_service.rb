# frozen_string_literal: true

require 'digest'

class DashboardDataService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(details: {}); @details = details; super("validation_error"); end
  end
  class TooExpensiveError < StandardError; end

  def initialize(user:, window: nil, sections: [])
    @user = user
    @window = window || { from: 1.year.ago, to: Time.current, tz: "UTC" }
    @sections = sections
  end

  def call
    # Preload everything you need in as few queries as possible
    lists = @user.owned_lists.select(:id, :name, :updated_at)
    list_ids = lists.pluck(:id)
    tasks = Task.where(list_id: list_ids).where(created_at: @window[:from]..@window[:to])

    # Build your payload based on requested sections
    data = {}
    
    if @sections.empty? || @sections.include?('inbox')
      data[:inbox_count] = tasks.where(completed_at: nil).count
    end
    
    if @sections.empty? || @sections.include?('overdue')
      overdue_count = tasks.where("due_at < ? AND completed_at IS NULL", Time.zone.now).count
      data[:overdue_count] = overdue_count
      data[:overdue_tasks_count] = overdue_count # Legacy field
    end
    
    if @sections.empty? || @sections.include?('velocity')
      data[:velocity] = velocity_series(tasks)
    end
    
    if @sections.empty? || @sections.include?('streaks')
      data[:streaks] = streaks(tasks)
    end

    # Add role-specific data
    if @user.client?
      data.merge!(client_specific_data(lists, tasks))
    else
      data.merge!(coach_specific_data(lists, tasks))
    end

    # Compute cache helpers
    lm = [lists.maximum(:updated_at), tasks.maximum(:updated_at)].compact.max
    dig = Digest::SHA1.hexdigest([@user.id, @window[:from].to_i, @window[:to].to_i, data.hash].join(":"))

    { **data, digest: dig, last_modified: lm }
  rescue ActiveRecord::QueryCanceled, ActiveRecord::StatementInvalid
    raise TooExpensiveError
  end

  def stats(group_by: "day", limit: 30)
    # Preload data efficiently
    lists = @user.owned_lists.select(:id, :updated_at)
    list_ids = lists.pluck(:id)
    tasks = Task.where(list_id: list_ids).where(created_at: @window[:from]..@window[:to])

    # Build time series data
    series = build_time_series(tasks, group_by, limit)
    
    # Build legacy stats format for backward compatibility
    stats_data = {
      total_tasks: tasks.count,
      completed_tasks: tasks.where.not(completed_at: nil).count,
      overdue_tasks: tasks.where("due_at < ? AND completed_at IS NULL", Time.zone.now).count,
      completion_rate: calculate_completion_rate(tasks),
      average_completion_time: 0, # TODO: Implement
      tasks_by_priority: {
        urgent: 0,
        high: 0,
        medium: 0,
        low: 0
      }
    }

    # Add role-specific stats
    if @user.client?
      stats_data.merge!(client_stats_data(tasks))
    else
      stats_data.merge!(coach_stats_data(tasks))
    end
    
    # Compute cache helpers
    lm = [lists.maximum(:updated_at), tasks.maximum(:updated_at)].compact.max
    dig = Digest::SHA1.hexdigest([@user.id, @window[:from].to_i, @window[:to].to_i, group_by, limit, series.hash].join(":"))

    { **stats_data, series: series, digest: dig, last_modified: lm }
  rescue ActiveRecord::QueryCanceled, ActiveRecord::StatementInvalid
    raise TooExpensiveError
  end

  private

  def client_specific_data(lists, tasks)
    {
      coaches_count: @user.coaches.count,
      completion_rate_this_week: calculate_completion_rate(tasks),
      recent_activity: recent_activity_summary,
      upcoming_deadlines: upcoming_deadlines_summary(tasks),
      # Legacy fields for backward compatibility
      blocking_tasks_count: tasks.joins(:escalation)
                                 .where(item_escalations: { blocking_app: true })
                                 .count,
      awaiting_explanation_count: tasks.where(requires_explanation_if_missed: true)
                                      .where("due_at < ? AND completed_at IS NULL", Time.current)
                                      .count
    }
  end

  def coach_specific_data(lists, tasks)
    # Simplified coach data to avoid expensive queries
    {
      clients_count: @user.clients.count,
      total_overdue_tasks: 0, # TODO: Implement efficiently
      pending_explanations: 0, # TODO: Implement efficiently
      active_relationships: @user.coaching_relationships_as_coach.count,
      recent_client_activity: [] # TODO: Implement efficiently
    }
  end

  def velocity_series(tasks)
    # Group completed tasks by date
    completed_tasks = tasks.where.not(completed_at: nil)
                          .group("DATE(completed_at)")
                          .count

    # Fill in missing dates with zeros
    (@window[:from].to_date..@window[:to].to_date).map do |date|
      {
        date: date.iso8601,
        completed: completed_tasks[date] || 0
      }
    end
  end

  def streaks(tasks)
    completed_dates = tasks.where.not(completed_at: nil)
                          .pluck(:completed_at)
                          .map(&:to_date)
                          .uniq
                          .sort

    return { current: 0, longest: 0 } if completed_dates.empty?

    current_streak = 0
    longest_streak = 0
    temp_streak = 0

    # Calculate streaks
    completed_dates.each_with_index do |date, index|
      if index == 0 || date == completed_dates[index - 1] + 1.day
        temp_streak += 1
      else
        longest_streak = [longest_streak, temp_streak].max
        temp_streak = 1
      end
    end

    longest_streak = [longest_streak, temp_streak].max

    # Calculate current streak (from today backwards)
    today = Time.zone.now.to_date
    current_streak = 0
    check_date = today

    while completed_dates.include?(check_date)
      current_streak += 1
      check_date -= 1.day
    end

    { current: current_streak, longest: longest_streak }
  end

  def build_time_series(tasks, group_by, limit)
    case group_by
    when 'day'
      group_by_day(tasks, limit)
    when 'week'
      group_by_week(tasks, limit)
    when 'month'
      group_by_month(tasks, limit)
    else
      group_by_day(tasks, limit)
    end
  end

  def group_by_day(tasks, limit)
    completed_tasks = tasks.where.not(completed_at: nil)
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

  def group_by_week(tasks, limit)
    completed_tasks = tasks.where.not(completed_at: nil)
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

  def group_by_month(tasks, limit)
    completed_tasks = tasks.where.not(completed_at: nil)
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

  def calculate_completion_rate(tasks)
    total = tasks.count
    return 0 if total == 0
    
    completed = tasks.where.not(completed_at: nil).count
    (completed.to_f / total * 100).round(1)
  end

  def recent_activity_summary
    # Get recent task events for the user
    recent_events = TaskEvent.includes(:task)
                             .joins(:task)
                             .where(tasks: { list: @user.lists })
                             .where("task_events.created_at >= ?", @window[:from])
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

  def upcoming_deadlines_summary(tasks)
    # Get tasks due in the next 7 days
    upcoming_tasks = tasks.includes(:list)
                         .where(status: :pending)
                         .where("due_at BETWEEN ? AND ?", Time.current, 7.days.from_now)
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

  def recent_client_activity_summary(client_tasks)
    # Get recent activity across all clients
    recent_events = TaskEvent.includes(:task, task: { list: :user })
                             .joins(:task)
                             .where(tasks: { id: client_tasks.select(:id) })
                             .where("task_events.created_at >= ?", @window[:from])
                             .order(created_at: :desc)
                             .limit(10)

    recent_events.map do |event|
      {
        id: event.id,
        client_name: event.task.list.user.name,
        task_title: event.task.title,
        action: event.kind,
        occurred_at: event.occurred_at
      }
    end
  end

  def client_stats_data(tasks)
    {
      # Client-specific stats (empty for now)
    }
  end

  def coach_stats_data(tasks)
    client_ids = @user.clients.pluck(:id)
    client_tasks = Task.where(list_id: List.where(user_id: client_ids).select(:id))
                      .where(created_at: @window[:from]..@window[:to])

    # Simplified client performance summary to avoid expensive queries
    client_performance = @user.clients.map do |client|
      {
        client_id: client.id,
        client_name: client.name,
        total_tasks: 0, # TODO: Implement efficiently
        completed_tasks: 0, # TODO: Implement efficiently
        completion_rate: 0.0
      }
    end

    {
      total_clients: @user.clients.count,
      active_clients: @user.coaching_relationships_as_coach.count,
      total_tasks_across_clients: client_tasks.count,
      completed_tasks_across_clients: client_tasks.where.not(completed_at: nil).count,
      average_client_completion_rate: 0.0, # TODO: Implement efficiently
      client_performance_summary: client_performance
    }
  end
end
