# frozen_string_literal: true

class RecurringTemplateUpdateService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(template:, params:)
    @template = template
    @params = params
  end

  def update!
    attrs = prepare_template_attributes(@params.to_h.symbolize_keys)

    unless @template.update(attrs)
      raise ValidationError.new("Validation failed", @template.errors.as_json)
    end

    # Propagate only fields that were provided, to FUTURE, INCOMPLETE instances
    propagate_changes_to_instances(attrs)

    @template
  end

  private

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

  def propagate_changes_to_instances(attrs)
    changed_fields = {}
    changed_fields[:title] = @template.title if attrs.key?(:title)
    changed_fields[:note] = @template.note if attrs.key?(:note)

    return unless changed_fields.present?

    Task.where(recurring_template_id: @template.id)
        .where("due_at > ?", Time.current)
        .where.not(status: Task.statuses[:done])
        .find_each { |inst| inst.update!(changed_fields) }
  end
end
