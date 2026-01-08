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
    day_anchor = (@task.due_at || Time.current).beginning_of_day
    next_time  = day_anchor + base_time.seconds_since_midnight
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
    candidate = begin
      now.change(day: (@task.due_at || now).day,
                 hour: base_time.hour, min: base_time.min, sec: base_time.sec)
    rescue
      nil
    end
    candidate ||= (now.beginning_of_month + base_time.seconds_since_midnight)
    candidate = candidate.next_month if candidate <= now
    candidate
  end

  def calculate_yearly_recurrence
    now = Time.current
    candidate = begin
      now.change(month: (@task.due_at || now).month, day: (@task.due_at || now).day,
                 hour: base_time.hour, min: base_time.min, sec: base_time.sec)
    rescue
      nil
    end
    candidate ||= now.beginning_of_year + base_time.seconds_since_midnight
    candidate = candidate.next_year if candidate <= now
    candidate
  end
end
