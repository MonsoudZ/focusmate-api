# frozen_string_literal: true

class RecurringTaskService
  def initialize(user)
    @user = user
  end

  # Create a recurring task template and its first instance
  def create_recurring_task(list:, params:, recurrence_params:)
    ActiveRecord::Base.transaction do
      # Advisory lock prevents duplicate templates from concurrent requests.
      # The lock is automatically released when the transaction ends.
      lock_key = Digest::MD5.hexdigest("recurring_task:#{@user.id}:#{list.id}:#{params[:title]}").to_i(16) & 0x7FFFFFFFFFFFFFFF
      ActiveRecord::Base.connection.exec_query("SELECT pg_advisory_xact_lock($1)", "advisory_lock", [ lock_key ])
      due_at = params[:due_at]

      # Create the template (hidden from normal queries)
      template = list.tasks.create!(
        creator: @user,
        title: params[:title],
        note: params[:note],
        color: params[:color],
        priority: params[:priority] || :no_priority,
        starred: params[:starred] || false,
        is_template: true,
        template_type: "recurring",
        is_recurring: true,
        recurrence_pattern: recurrence_params[:pattern],
        recurrence_interval: recurrence_params[:interval] || 1,
        recurrence_days: recurrence_params[:days],
        recurrence_time: extract_time(due_at),
        recurrence_end_date: recurrence_params[:end_date],
        recurrence_count: recurrence_params[:count],
        due_at: due_at,
        status: :pending
      )

      # Create the first instance with the exact due_at from params
      first_instance = generate_instance(template, instance_number: 1, due_date: due_at)

      { template: template, instance: first_instance }
    end
  end

  # Generate the next instance when a task is completed
  def generate_next_instance(completed_instance)
    template = completed_instance.template
    return nil unless template&.is_template && template.template_type == "recurring"
    return nil if recurrence_ended?(template, completed_instance)

    next_due_date = calculate_next_due_date(template, completed_instance.due_at)
    return nil if next_due_date.nil?
    return nil if template.recurrence_end_date && next_due_date.to_date > template.recurrence_end_date

    generate_instance(
      template,
      instance_number: (completed_instance.instance_number || 0) + 1,
      due_date: next_due_date
    )
  end

  private

  def generate_instance(template, instance_number:, due_date:)
    template.instances.create!(
      list: template.list,
      creator: template.creator,
      title: template.title,
      note: template.note,
      color: template.color,
      priority: template.priority,
      starred: template.starred,
      is_template: false,
      template_type: nil,
      template_id: template.id,
      is_recurring: false,
      due_at: due_date,
      instance_date: due_date&.to_date,
      instance_number: instance_number,
      status: :pending,
      strict_mode: template.strict_mode,
      requires_explanation_if_missed: template.requires_explanation_if_missed
    )
  end

  def calculate_next_due_date(template, last_due_date)
    return nil unless last_due_date

    interval = template.recurrence_interval || 1
    base_time = template.recurrence_time || last_due_date

    case template.recurrence_pattern
    when "daily"
      next_date = last_due_date.to_date + interval.days
      combine_date_and_time(next_date, base_time)
    when "weekly"
      days = template.recurrence_days || [ last_due_date.wday ]
      next_date = find_next_weekday(last_due_date.to_date + 1.day, days, interval)
      combine_date_and_time(next_date, base_time)
    when "monthly"
      next_date = last_due_date.to_date + interval.months
      combine_date_and_time(next_date, base_time)
    when "yearly"
      next_date = last_due_date.to_date + interval.years
      combine_date_and_time(next_date, base_time)
    else
      nil
    end
  end

  def find_next_weekday(from_date, allowed_days, interval = 1)
    current = from_date
    start_week = from_date.beginning_of_week

    100.times do
      current_week = current.beginning_of_week
      weeks_diff = ((current_week - start_week) / 7).to_i

      if allowed_days.include?(current.wday) && (weeks_diff % interval).zero?
        return current
      end

      current += 1.day
    end

    from_date + 7.days
  end

  def recurrence_ended?(template, last_instance)
    return true if template.recurrence_end_date && Date.current > template.recurrence_end_date
    return true if template.recurrence_count && last_instance.instance_number >= template.recurrence_count
    false
  end

  def combine_date_and_time(date, time)
    return date.to_datetime.beginning_of_day if time.nil?

    Time.zone.local(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.min,
      0
    )
  end

  def extract_time(datetime)
    return nil if datetime.nil?
    datetime
  end
end
