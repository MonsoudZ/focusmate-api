# frozen_string_literal: true

class TaskCreationService
  include TimeParsing

  def self.call!(list:, user:, params:)
    new(list:, user:, params:).call!
  end

  def initialize(list:, user:, params:)
    @list = list
    @user = user
    @params = normalize_params(params)
  end

  def call!
    task = nil

    ActiveRecord::Base.transaction do
      task = @list.tasks.new(task_attributes)
      task.creator = @user
      task.save!

      create_subtasks(task) if subtask_titles.present?
    end

    track_analytics(task)

    task
  end

  private

  def normalize_params(params)
    # Convert ActionController::Parameters to hash if needed
    params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
    params = params.with_indifferent_access

    # Handle iOS naming conventions
    params[:title] ||= params.delete(:name)
    params[:note] ||= params.delete(:description)
    params[:due_at] ||= parse_due_date(params)

    params
  end

  def parse_due_date(params)
    # Priority: due_at > dueDate > due_date
    raw_value = params[:due_at] || params[:dueDate] || params[:due_date]
    parse_time(raw_value)
  end

  def task_attributes
    {
      title: @params[:title],
      note: @params[:note],
      due_at: @params[:due_at],
      priority: @params[:priority] || :no_priority,
      color: @params[:color],
      starred: @params[:starred] || false,
      strict_mode: @params.fetch(:strict_mode, true),
      notification_interval_minutes: @params[:notification_interval_minutes],
      requires_explanation_if_missed: @params[:requires_explanation_if_missed] || false,
      visibility: @params[:visibility] || :visible_to_all,
      parent_task_id: @params[:parent_task_id],

      # Location-based
      location_based: @params[:location_based] || false,
      location_name: @params[:location_name],
      location_latitude: @params[:location_latitude],
      location_longitude: @params[:location_longitude],
      location_radius_meters: @params[:location_radius_meters],
      notify_on_arrival: @params[:notify_on_arrival],
      notify_on_departure: @params[:notify_on_departure],

      # Recurrence
      is_recurring: @params[:is_recurring] || false,
      recurrence_pattern: @params[:recurrence_pattern],
      recurrence_interval: @params[:recurrence_interval],
      recurrence_days: @params[:recurrence_days],
      recurrence_time: @params[:recurrence_time],
      recurrence_end_date: @params[:recurrence_end_date],
      recurrence_count: @params[:recurrence_count],

      # Tags
      tag_ids: @params[:tag_ids]
    }.compact
  end

  def subtask_titles
    @params[:subtasks]
  end

  def create_subtasks(parent_task)
    subtask_titles.each do |title|
      next if title.blank?

      @list.tasks.create!(
        title: title,
        creator: @user,
        parent_task: parent_task,
        due_at: parent_task.due_at,
        strict_mode: parent_task.strict_mode,
        status: :pending
      )
    end
  end

  def track_analytics(task)
    AnalyticsTracker.task_created(task, @user)
  end
end
