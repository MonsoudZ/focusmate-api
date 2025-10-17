class RecurringTaskGeneratorWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :default, retry: 2

  def perform
    Rails.logger.info "[RecurringTaskGeneratorWorker] Starting recurring task generation at #{Time.current}"
    
    # Find all recurring templates
    templates = Task.templates.includes(:list, :recurring_instances)
    
    Rails.logger.info "[RecurringTaskGeneratorWorker] Found #{templates.count} recurring templates"
    
    templates.find_each do |template|
      generate_instances_for_template(template)
    end
    
    Rails.logger.info "[RecurringTaskGeneratorWorker] Completed recurring task generation"
  end

  private

  def generate_instances_for_template(template)
    # Calculate when the next instance should be due
    next_due = template.calculate_next_due_date
    
    return unless next_due
    
    # Check if we've reached the end date
    if template.recurrence_end_date.present? && next_due > template.recurrence_end_date
      Rails.logger.info "[RecurringTaskGeneratorWorker] Template ##{template.id} has reached end date"
      return
    end
    
    # Generate instances for the next 7 days
    instances_to_generate = []
    current_date = next_due
    
    7.times do
      break if template.recurrence_end_date.present? && current_date > template.recurrence_end_date
      
      # Check if instance already exists for this date
      existing = template.recurring_instances.find_by(
        'DATE(due_at) = ?', current_date.to_date
      )
      
      if existing.nil?
        instances_to_generate << current_date
      end
      
      # Calculate next date based on pattern
      current_date = advance_date(current_date, template)
    end
    
    # Create the instances
    instances_to_generate.each do |due_date|
      create_instance(template, due_date)
    end
    
    if instances_to_generate.any?
      Rails.logger.info "[RecurringTaskGeneratorWorker] Generated #{instances_to_generate.count} instances for template ##{template.id}"
    end
    
  rescue => e
    Rails.logger.error "[RecurringTaskGeneratorWorker] Error processing template ##{template.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def create_instance(template, due_date)
    # Set the time component if specified
    if template.recurrence_time.present?
      due_date = due_date.change(
        hour: template.recurrence_time.hour,
        min: template.recurrence_time.min
      )
    end
    
    instance = template.recurring_instances.create!(
      list: template.list,
      creator: template.creator,
      title: template.title,
      description: template.description,
      due_at: due_date,
      priority: template.priority,
      can_be_snoozed: template.can_be_snoozed,
      notification_interval_minutes: template.notification_interval_minutes,
      requires_explanation_if_missed: template.requires_explanation_if_missed,
      location_based: template.location_based,
      location_latitude: template.location_latitude,
      location_longitude: template.location_longitude,
      location_radius_meters: template.location_radius_meters,
      location_name: template.location_name,
      notify_on_arrival: template.notify_on_arrival,
      notify_on_departure: template.notify_on_departure
    )
    
    Rails.logger.info "[RecurringTaskGeneratorWorker] Created instance ##{instance.id} for template ##{template.id}, due #{due_date}"
    
    # Notify the user about the new task
    NotificationService.recurring_task_generated(instance)
    
    instance
  end

  def advance_date(date, template)
    case template.recurrence_pattern
    when 'daily'
      date + template.recurrence_interval.days
    when 'weekly'
      next_date = date + template.recurrence_interval.weeks
      
      # If specific days are set, advance to next matching day
      if template.recurrence_days.present?
        while !template.recurrence_days.include?(next_date.wday)
          next_date += 1.day
        end
      end
      
      next_date
    when 'monthly'
      date + template.recurrence_interval.months
    when 'custom'
      date + template.recurrence_interval.days
    else
      date + 1.day
    end
  end
end
