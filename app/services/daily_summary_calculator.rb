# frozen_string_literal: true

class DailySummaryCalculator
  def initialize(user:, date:)
    @user = user
    @date = date
  end

  def call
    {
      date: @date,
      tasks_completed: tasks_completed,
      tasks_missed: tasks_missed,
      tasks_overdue: tasks_overdue,
      focus_minutes: focus_minutes,
      completion_rate: completion_rate,
      priority: priority,
      positive: positive?,
      negative: negative?,
      has_overdue_tasks: has_overdue_tasks?,
      total_tasks: total_tasks,
      title: title,
      description: description
    }
  end

  private

  def tasks_completed
    @user.created_tasks.where(status: :done, updated_at: @date.all_day).count
  end

  def tasks_missed
    @user.created_tasks.where(status: :pending, due_at: @date.all_day).count
  end

  def tasks_overdue
    @user.created_tasks.where(status: :pending, due_at: ...@date.beginning_of_day).count
  end

  def focus_minutes
    # Placeholder for focus sessions - would need a Session model
    0
  end

  def total_tasks
    tasks_completed + tasks_missed
  end

  def completion_rate
    total = total_tasks
    return 0.0 if total.zero?
    ((tasks_completed.to_f / total) * 100).round(2)
  end

  def positive?
    tasks_completed > tasks_missed
  end

  def negative?
    tasks_missed > tasks_completed
  end

  def has_overdue_tasks?
    tasks_overdue.positive?
  end

  def priority
    return "high" if tasks_overdue.positive?
    return "medium" if completion_rate < 80.0 && completion_rate >= 50.0
    "low"
  end

  def title
    "Daily Summary - #{@date.strftime('%B %d, %Y')}"
  end

  def description
    "#{tasks_completed} completed, #{tasks_missed} missed, #{tasks_overdue} overdue (#{completion_rate}%)"
  end
end
