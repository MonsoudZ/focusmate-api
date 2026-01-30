# frozen_string_literal: true

class StreakService
  def initialize(user)
    @user = user
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

  def check_previous_days!
    today = Date.current
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
    today = Date.current

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

    total_count = base_scope.count
    return :no_tasks if total_count.zero?

    completed_count = base_scope.where(status: "done").count
    total_count == completed_count ? :all_completed : :incomplete
  end

  def tasks_due_on(date)
    @user.created_tasks
         .where(due_at: date.beginning_of_day..date.end_of_day)
         .where(parent_task_id: nil)
         .where(deleted_at: nil)
  end

  def update_longest_streak!
    if @user.current_streak > @user.longest_streak
      @user.longest_streak = @user.current_streak
    end
  end
end
