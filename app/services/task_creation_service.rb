# frozen_string_literal: true

class TaskCreationService < ApplicationService
  include TimeParsing

  PERMITTED_SCALAR_PARAMS = %i[
    title note due_at priority color starred strict_mode
    notification_interval_minutes requires_explanation_if_missed visibility
    parent_task_id location_based location_name location_latitude
    location_longitude location_radius_meters notify_on_arrival
    notify_on_departure is_recurring recurrence_pattern recurrence_interval
    recurrence_time recurrence_end_date recurrence_count name description
    dueDate due_date
  ].freeze
  PERMITTED_ARRAY_PARAMS = { tag_ids: [], recurrence_days: [], subtasks: [] }.freeze

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
    params = sanitize_params(params).with_indifferent_access

    # Handle iOS naming conventions
    params[:title] ||= params.delete(:name)
    params[:note] ||= params.delete(:description)
    params[:due_at] ||= parse_due_date(params)

    params
  end

  def sanitize_params(params)
    case params
    when ActionController::Parameters
      params.permit(*PERMITTED_SCALAR_PARAMS, PERMITTED_ARRAY_PARAMS).to_h
    when Hash
      params.with_indifferent_access.slice(
        *PERMITTED_SCALAR_PARAMS,
        :tag_ids,
        :recurrence_days,
        :subtasks
      )
    else
      {}
    end
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

      # Tags (validated for ownership)
      tag_ids: validated_tag_ids
    }.compact
  end

  def validated_tag_ids
    ids = @params[:tag_ids]
    return nil if ids.blank?

    owned_ids = @user.tags.where(id: ids).pluck(:id)
    invalid_ids = ids.map(&:to_i) - owned_ids
    if invalid_ids.any?
      raise ApplicationError::Forbidden.new("Cannot use tags that don't belong to you", code: "invalid_tag_ids")
    end
    owned_ids
  end

  def subtask_titles
    @params[:subtasks]
  end

  def create_subtasks(parent_task)
    valid_titles = subtask_titles.reject(&:blank?)
    return if valid_titles.empty?

    valid_titles.each do |title|
      @list.tasks.create!(
        title: title,
        creator: @user,
        parent_task: parent_task,
        due_at: parent_task.due_at,
        strict_mode: parent_task.strict_mode,
        status: :pending,
        visibility: :visible_to_all,
        priority: :no_priority,
        starred: false
      )
    end
  end

  def track_analytics(task)
    AnalyticsTracker.task_created(task, @user)
  end
end
