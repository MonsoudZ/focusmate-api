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
#   query.overdue        # Tasks past due
#   query.due_today      # Tasks due today
#   query.completed_today # Tasks completed today
#   query.all_for_today  # Combined hash for API response
#
class TodayTasksQuery
  attr_reader :user, :timezone

  def initialize(user, timezone: nil)
    @user = user
    @timezone = timezone || user.timezone || "UTC"
  end

  # Tasks that are past due and not completed
  def overdue
    base_scope
      .where("due_at < ?", beginning_of_today)
      .where.not(status: "done")
      .order(due_at: :asc)
  end

  # Tasks due today that are not completed
  def due_today
    base_scope
      .where(due_at: today_range)
      .where.not(status: "done")
      .order(due_at: :asc)
  end

  # Tasks that are due today (regardless of completion status)
  def all_due_today
    base_scope
      .where(due_at: today_range)
      .order(due_at: :asc)
  end

  # Tasks completed today
  def completed_today(limit: 10)
    base_scope
      .where(completed_at: today_range)
      .where(status: "done")
      .order(completed_at: :desc)
      .limit(limit)
  end

  # Tasks due in the next few days (not including today)
  def upcoming(days: 7, limit: 20)
    base_scope
      .where(due_at: end_of_today..days.days.from_now.end_of_day)
      .where.not(status: "done")
      .order(due_at: :asc)
      .limit(limit)
  end

  # Anytime tasks (due_at is nil or far future placeholder)
  def anytime
    base_scope
      .where(due_at: nil)
      .where.not(status: "done")
      .order(created_at: :desc)
  end

  # Combined data for Today API endpoint
  def all_for_today
    {
      overdue: overdue.to_a,
      due_today: due_today.to_a,
      completed_today: completed_today.to_a
    }
  end

  # Statistics for Today view
  def stats
    all_today = all_due_today.to_a
    completed = all_today.count { |t| t.status == "done" }
    total = all_today.count

    {
      total_due_today: total,
      completed_today: completed,
      remaining_today: total - completed,
      overdue_count: overdue.count,
      completion_percentage: total > 0 ? (completed.to_f / total * 100).round : 0
    }
  end

  private

  def base_scope
    Task
      .joins(:list)
      .where(lists: { user_id: user.id, deleted_at: nil })
      .where(parent_task_id: nil)
      .where(is_template: [ false, nil ])
      .where(deleted_at: nil)
      .includes(:list, :tags, :creator)
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
