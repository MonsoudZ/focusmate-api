# frozen_string_literal: true

class StreakService
  def initialize(user)
    @user = user
    @user_zone = resolve_timezone(user.timezone)
  end

  # Call this when user opens the app or completes a task
  def update_streak!
    @user.with_lock do
      check_previous_days!
      check_today!
      @user.save!
    end
  end

  private

  def user_today
    Time.current.in_time_zone(@user_zone).to_date
  end

  def resolve_timezone(value)
    return "UTC" if value.blank?
    ActiveSupport::TimeZone[value.to_s] ? value.to_s : "UTC"
  end

  def check_previous_days!
    today = user_today
    last_checked = @user.last_streak_date

    # First time user
    return if last_checked.nil?

    # Already checked today
    return if last_checked == today

    # Check each day since last check
    date_to_check = last_checked + 1.day

    while date_to_check < today
      result = check_day_completion(date_to_check)

      case result
      when :all_completed
        @user.current_streak += 1
        update_longest_streak!
      when :incomplete
        @user.current_streak = 0
      end
      # :no_tasks - streak unchanged

      date_to_check += 1.day
    end
  end

  def check_today!
    today = user_today

    return if @user.last_streak_date == today

    result = check_day_completion(today)

    case result
    when :all_completed
      @user.current_streak += 1
      update_longest_streak!
      @user.last_streak_date = today
    when :no_tasks
      # No tasks due today - neutral day, just mark as checked
      @user.last_streak_date = today
    end
    # :incomplete - Tasks due but not all completed yet
    # Don't update last_streak_date, streak will be evaluated later
  end

  # Returns :all_completed, :incomplete, or :no_tasks
  # Uses efficient database queries instead of loading all tasks into memory
  def check_day_completion(date)
    base_scope = tasks_due_on(date)

    total_count, completed_count = completion_counts(base_scope)
    return :no_tasks if total_count.zero?

    total_count == completed_count ? :all_completed : :incomplete
  end

  def tasks_due_on(date)
    zone = ActiveSupport::TimeZone[@user_zone]
    day_start = zone.local(date.year, date.month, date.day).beginning_of_day
    day_end = day_start.end_of_day

    @user.created_tasks
         .where(due_at: day_start..day_end)
         .where(parent_task_id: nil)
         .where(deleted_at: nil)
  end

  def update_longest_streak!
    if @user.current_streak > @user.longest_streak
      @user.longest_streak = @user.current_streak
    end
  end

  def completion_counts(scope)
    task_table = Task.arel_table
    done_status = Task.statuses.fetch("done")

    total_count = task_table[:id].count
    completed_count = Arel::Nodes::Case.new
                                      .when(task_table[:status].eq(done_status))
                                      .then(1)
                                      .sum

    totals = scope.pick(total_count, completed_count)
    [ totals[0].to_i, totals[1].to_i ]
  end
end
