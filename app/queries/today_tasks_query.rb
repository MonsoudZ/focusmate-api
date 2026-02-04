# frozen_string_literal: true

# TodayTasksQuery encapsulates the complex queries for the Today view.
#
# Provides methods for fetching:
#   - Overdue tasks (past due, not completed)
#   - Tasks due today (not completed)
#   - Tasks completed today
#   - Upcoming tasks (due soon but not today)
#
# Usage:
#   query = TodayTasksQuery.new(user)
#   result = query.fetch_all  # Single method, no duplicate queries
#   result[:overdue]          # Cached tasks
#   result[:stats]            # Computed from cached data
#
class TodayTasksQuery
  attr_reader :user, :timezone

  def initialize(user, timezone: nil)
    @user = user
    @timezone = timezone || user.timezone || "UTC"
    @cached_data = nil
  end

  # Single entry point that fetches all data efficiently
  # Returns hash with :overdue, :due_today, :completed_today, :stats
  def fetch_all
    return @cached_data if @cached_data

    # Execute queries once and cache results
    overdue_tasks = overdue.to_a
    due_today_tasks = due_today.to_a
    completed_today_tasks = completed_today.to_a

    # Compute stats from already-loaded data (no additional queries)
    stats = compute_stats(
      overdue_tasks: overdue_tasks,
      due_today_tasks: due_today_tasks,
      completed_today_tasks: completed_today_tasks
    )

    @cached_data = {
      overdue: overdue_tasks,
      due_today: due_today_tasks,
      completed_today: completed_today_tasks,
      stats: stats
    }
  end

  # Tasks that are past due and not completed
  def overdue
    base_scope
      .where("tasks.due_at < ?", beginning_of_today)
      .where.not(status: "done")
      .order("tasks.due_at ASC")
  end

  # Tasks due today that are not completed
  def due_today
    base_scope
      .where(tasks: { due_at: today_range })
      .where.not(status: "done")
      .order("tasks.due_at ASC")
  end

  # Tasks that are due today (regardless of completion status)
  def all_due_today
    base_scope
      .where(tasks: { due_at: today_range })
      .order("tasks.due_at ASC")
  end

  # Tasks completed today
  def completed_today(limit: 10)
    base_scope
      .where(tasks: { completed_at: today_range })
      .where(status: "done")
      .order("tasks.completed_at DESC")
      .limit(limit)
  end

  # Tasks due in the next few days (not including today)
  def upcoming(days: 7, limit: 20)
    base_scope
      .where(tasks: { due_at: end_of_today..days.days.from_now.end_of_day })
      .where.not(status: "done")
      .order("tasks.due_at ASC")
      .limit(limit)
  end

  # Anytime tasks (due_at is nil or far future placeholder)
  def anytime
    base_scope
      .where(tasks: { due_at: nil })
      .where.not(status: "done")
      .order("tasks.created_at DESC")
  end

  # Legacy method - use fetch_all instead for better performance
  def all_for_today
    data = fetch_all
    {
      overdue: data[:overdue],
      due_today: data[:due_today],
      completed_today: data[:completed_today]
    }
  end

  # Legacy method - use fetch_all instead for better performance
  def stats
    fetch_all[:stats]
  end

  private

  def compute_stats(overdue_tasks:, due_today_tasks:, completed_today_tasks:)
    # Total due today = incomplete + completed today (that were due today)
    # Note: completed_today includes tasks completed today regardless of original due date
    # For accurate "due today" stats, we need to count tasks that were due today
    total_due = due_today_tasks.size + completed_today_tasks.count { |t| t.due_at && today_range.cover?(t.due_at) }
    completed = completed_today_tasks.count { |t| t.due_at && today_range.cover?(t.due_at) }
    remaining = due_today_tasks.size

    {
      total_due_today: total_due,
      completed_today: completed_today_tasks.size,
      remaining_today: remaining,
      overdue_count: overdue_tasks.size,
      completion_percentage: total_due > 0 ? ((completed.to_f / total_due) * 100).round : 0
    }
  end

  def base_scope
    Task
      .joins(:list)
      .where(list_id: accessible_list_ids)
      .where(lists: { deleted_at: nil })
      .where(parent_task_id: nil)
      .where(is_template: [ false, nil ])
      .where(deleted_at: nil)
      .visible_to_user(user)
      .includes(:tags, :creator, :subtasks, { list: :user }, { reschedule_events: :user })
  end

  def accessible_list_ids
    @accessible_list_ids ||= List
      .left_joins(:memberships)
      .where("lists.user_id = :uid OR memberships.user_id = :uid", uid: user.id)
      .where(deleted_at: nil)
      .select(:id)
  end

  def beginning_of_today
    Time.current.in_time_zone(timezone).beginning_of_day
  end

  def end_of_today
    Time.current.in_time_zone(timezone).end_of_day
  end

  def today_range
    beginning_of_today..end_of_today
  end
end
