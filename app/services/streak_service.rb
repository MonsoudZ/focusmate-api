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
      if had_tasks_due?(date_to_check) && !completed_all_tasks?(date_to_check)
        # Streak broken
        @user.current_streak = 0
      elsif had_tasks_due?(date_to_check) && completed_all_tasks?(date_to_check)
        # Streak continues
        @user.current_streak += 1
        update_longest_streak!
      end
      # Days with no tasks due: streak unchanged

      date_to_check += 1.day
    end
  end

  def check_today!
    today = Date.current

    return if @user.last_streak_date == today

    if had_tasks_due?(today) && completed_all_tasks?(today)
      @user.current_streak += 1
      update_longest_streak!
      @user.last_streak_date = today
    elsif had_tasks_due?(today)
      # Tasks due but not all completed yet - don't update last_streak_date
      # Streak will be evaluated at end of day or next app open
    else
      # No tasks due today - neutral day, just mark as checked
      @user.last_streak_date = today
    end
  end

  def had_tasks_due?(date)
    tasks_due_on(date).exists?
  end

  def completed_all_tasks?(date)
    due_tasks = tasks_due_on(date)
    return false if due_tasks.empty?

    due_tasks.all? { |task| task.status == "done" }
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
