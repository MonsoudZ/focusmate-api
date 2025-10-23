# frozen_string_literal: true

class TaskCreationService
  def initialize(list, user, params)
    @list = list
    @user = user
    @params = params
  end

  def call
    # Preserve subtasks before normalize_parameters
    subtasks = @params[:subtasks]
    normalize_parameters
    create_task
    create_subtasks(subtasks) if subtasks.present?
    setup_notifications
    @task
  end

  private

  def normalize_parameters
    @attrs = @params.to_h

    # Handle iOS-specific parameters
    handle_ios_parameters
    set_default_values
    clean_parameters
  end

  def handle_ios_parameters
    # iOS uses 'name' instead of 'title'
    @attrs[:title] = @params[:name] if @params[:name].present?

    # iOS uses 'description' instead of 'note'
    @attrs[:note] = @params[:description] if @params[:description].present?

    # Handle different date formats
    handle_date_parameters
  end

  def handle_date_parameters
    @attrs[:due_at] = extract_due_at(@params)
  end

  def extract_due_at(h)
    return parse_epoch(h[:dueDate]) if h.key?(:dueDate) # epoch seconds
    return parse_time(h[:due_date]) if h.key?(:due_date) # ISO8601
    return parse_time(h[:due_at])   if h.key?(:due_at)   # ISO8601
    nil
  rescue ArgumentError
    nil
  end

  def parse_epoch(v)
    return nil if v.blank?
    Time.at(v.to_i)
  rescue ArgumentError
    nil
  end

  def parse_time(v)
    return nil if v.blank?
    case v
    when Time   then v.in_time_zone
    when String
      begin
        Time.iso8601(v).in_time_zone # preserves instant if "Z"/offset included
      rescue ArgumentError
        Time.zone.parse(v.to_s)
      end
    end
  rescue StandardError
    nil
  end

  def set_default_values
    @attrs[:strict_mode] = true if @attrs[:strict_mode].nil?
    
    # Handle boolean attributes
    @attrs[:can_be_snoozed] = boolean(@attrs[:can_be_snoozed]) unless @attrs[:can_be_snoozed].nil?
    @attrs[:requires_explanation_if_missed] = boolean(@attrs[:requires_explanation_if_missed]) unless @attrs[:requires_explanation_if_missed].nil?
    @attrs[:location_based] = boolean(@attrs[:location_based]) unless @attrs[:location_based].nil?
    @attrs[:is_recurring] = boolean(@attrs[:is_recurring]) unless @attrs[:is_recurring].nil?
  end

  def boolean(value)
    case value
    when true, false then value
    when "true", "1", 1 then true
    when "false", "0", 0, nil then false
    else false
    end
  end

  def clean_parameters
    # Remove iOS-specific parameters that shouldn't go to the model
    @attrs.delete(:name)
    @attrs.delete(:dueDate)
    @attrs.delete(:description)
    @attrs.delete(:due_date)
    @attrs.delete(:subtasks)  # Handle subtasks separately
  end

  def create_task
    @task = @list.tasks.build(@attrs)
    @task.creator = @user
    
    # Fallback only if still required by validations (e.g., strict_mode => due_at presence)
    if @task.due_at.blank? && @task.strict_mode
      @task.due_at = 1.hour.from_now
    end
    
    @task.save!
  end

  def create_subtasks(subtasks)
    subtasks.each do |subtask_title|
      @task.subtasks.create!(
        list: @list,
        creator: @user,
        title: subtask_title,
        due_at: @task.due_at,
        strict_mode: @task.strict_mode
      )
    end
  end

  def setup_notifications
    # Notify client if coach created it
    NotificationService.new_item_assigned(@task) if @task.created_by_coach?

    # Set up geofencing if location-based
    # if @task.location_based?
    #   GeofencingService.setup_geofence(@task)
    # end
  end
end
