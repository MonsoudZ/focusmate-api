# frozen_string_literal: true

class RecurringTemplateCreationService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end
  class NotFoundError < StandardError; end

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def create!
    list = find_authorized_list
    attrs = prepare_template_attributes(@params.to_h.symbolize_keys)
    template = list.tasks.new(attrs.merge(creator: @user))

    unless template.save
      raise ValidationError.new("Validation failed", template.errors.as_json)
    end

    template
  end

  private

  def find_authorized_list
    list_id = @params[:list_id]

    if list_id.blank?
      raise NotFoundError, "List not found"
    end

    list = @user&.owned_lists&.find_by(id: list_id) ||
           List.find_by(id: list_id, user_id: @user.id)

    unless list
      raise NotFoundError, "List not found"
    end

    list
  end

  def prepare_template_attributes(attrs)
    attrs[:note] = attrs.delete(:description) if attrs.key?(:description)
    attrs[:is_recurring] = true
    attrs[:recurring_template_id] = nil
    attrs[:strict_mode] ||= false

    # due_at is required by the model; seed it if missing
    attrs[:due_at] ||= begin
      if attrs[:recurrence_time].present?
        t = Time.zone.parse(attrs[:recurrence_time].to_s) rescue nil
        if t
          (Time.zone.today.to_time + t.seconds_since_midnight)
        else
          Time.current
        end
      else
        Time.current
      end
    end

    if attrs.key?(:recurrence_days)
      days = Array(attrs[:recurrence_days])
      # Convert day names to numbers if needed
      day_map = { "sunday" => 0, "monday" => 1, "tuesday" => 2, "wednesday" => 3, "thursday" => 4, "friday" => 5, "saturday" => 6 }
      attrs[:recurrence_days] = days.map { |day| day_map[day.to_s.downcase] || day.to_i }
    end

    attrs
  end
end
