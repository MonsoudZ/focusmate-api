class TaskRecurrenceService
  def initialize(task)
    @task = task
  end

  def calculate_next_due_date
    return nil unless @task.is_recurring?

    case @task.recurrence_pattern
    when "daily"   then calculate_daily_recurrence
    when "weekly"  then calculate_weekly_recurrence
    when "monthly" then calculate_monthly_recurrence
    when "yearly"  then calculate_yearly_recurrence
    else nil
    end
  end

  def generate_next_instance
    return nil unless @task.is_recurring?
    return nil if @task.recurrence_end_date.present? && @task.recurrence_end_date < Time.current

    next_due_at = calculate_next_due_date
    return nil unless next_due_at

    instance = @task.list.tasks.build(
      title: @task.title,
      note: @task.note,
      due_at: next_due_at,
      strict_mode: @task.strict_mode,
      can_be_snoozed: @task.can_be_snoozed,
      notification_interval_minutes: @task.notification_interval_minutes,
      requires_explanation_if_missed: @task.requires_explanation_if_missed,
      location_based: @task.location_based,
      location_latitude: @task.location_latitude,
      location_longitude: @task.location_longitude,
      location_radius_meters: @task.location_radius_meters,
      location_name: @task.location_name,
      notify_on_arrival: @task.notify_on_arrival,
      notify_on_departure: @task.notify_on_departure,
      is_recurring: false,
      template_id: @task.id,
      creator: @task.creator,
      status: :pending
    )
    instance.save ? instance : nil
  end

  private

  def base_time
    @task.recurrence_time || (@task.due_at || Time.current)
  end

  def calculate_daily_recurrence
    day_anchor = (@task.due_at || Time.current).to_date
    next_time  = Time.zone.local(day_anchor.year, day_anchor.month, day_anchor.day,
                                  base_time.hour, base_time.min, base_time.sec)
    next_time += 1.day if next_time <= Time.current
    next_time
  end

  def calculate_weekly_recurrence
    return nil unless @task.recurrence_days.present?

    days = @task.recurrence_days.map(&:to_i).sort
    now  = Time.current
    days.each do |wday|
      candidate = now.beginning_of_week + wday.days
      candidate = candidate.change(hour: base_time.hour, min: base_time.min, sec: base_time.sec)
      return candidate if candidate > now
    end
    first = days.first
    (now.beginning_of_week + 1.week + first.days).change(
      hour: base_time.hour, min: base_time.min, sec: base_time.sec
    )
  end

  def calculate_monthly_recurrence
    now = Time.current
    target_day = (@task.due_at || now).day
    # Snap to last day of month when target day doesn't exist (e.g. day 31 in a 30-day month)
    actual_day = [target_day, Time.days_in_month(now.month, now.year)].min
    candidate = now.change(day: actual_day,
                           hour: base_time.hour, min: base_time.min, sec: base_time.sec)
    if candidate <= now
      next_month = now.next_month
      actual_day = [target_day, Time.days_in_month(next_month.month, next_month.year)].min
      candidate = next_month.change(day: actual_day,
                                    hour: base_time.hour, min: base_time.min, sec: base_time.sec)
    end
    candidate
  end

  def calculate_yearly_recurrence
    now = Time.current
    target = @task.due_at || now
    target_month = target.month
    target_day = target.day
    # Snap to last day of month when target day doesn't exist (e.g. Feb 29 in non-leap year)
    actual_day = [target_day, Time.days_in_month(target_month, now.year)].min
    candidate = now.change(month: target_month, day: actual_day,
                           hour: base_time.hour, min: base_time.min, sec: base_time.sec)
    if candidate <= now
      next_year = now.year + 1
      actual_day = [target_day, Time.days_in_month(target_month, next_year)].min
      candidate = Time.zone.local(next_year, target_month, actual_day,
                                  base_time.hour, base_time.min, base_time.sec)
    end
    candidate
  end
end
