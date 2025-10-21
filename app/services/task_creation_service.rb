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
    if @params[:dueDate].present? && @attrs[:due_at].blank?
      # iOS sends epoch seconds
      begin
        @attrs[:due_at] = Time.at(@params[:dueDate].to_i)
      rescue
        # ignore bad format
      end
    end

    if @params[:due_date].present? && @attrs[:due_at].blank?
      # Handle ISO8601 date format
      begin
        @attrs[:due_at] = Time.parse(@params[:due_date])
      rescue
        # ignore bad format
      end
    end
  end

  def set_default_values
    @attrs[:strict_mode] = true if @attrs[:strict_mode].nil?
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
