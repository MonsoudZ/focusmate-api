# frozen_string_literal: true

class CoachingRelationshipPreferencesService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError; end

  def initialize(relationship:, current_user:, params:)
    @relationship = relationship
    @current_user = current_user
    @params = params
  end

  def update!
    validate_authorization!

    changes = prepare_changes(@params.to_h.symbolize_keys)

    update_relationship(changes)

    @relationship
  end

  private

  def validate_authorization!
    unless @current_user.id == @relationship.coach_id
      raise UnauthorizedError, "Only coaches can update preferences"
    end
  end

  def prepare_changes(changes)
    # Remove timezone - it's accepted but not stored (for future use)
    changes.delete(:timezone)

    # Convert HH:MM string to Time object if provided
    if changes.key?(:daily_summary_time)
      changes[:daily_summary_time] = parse_time(changes[:daily_summary_time])
    end

    # Convert string booleans to actual booleans
    [:notify_on_completion, :notify_on_missed_deadline, :send_daily_summary].each do |key|
      if changes.key?(key)
        changes[key] = cast_boolean(changes[key])
      end
    end

    changes
  end

  def parse_time(val)
    return nil if val.blank?

    if val.is_a?(String)
      # Validate HH:MM format
      if val.match?(/\A([01]?\d|2[0-3]):[0-5]\d\z/)
        # Parse as time today (Rails will store just the time part)
        Time.zone.parse(val)
      elsif val.present?
        raise ValidationError, "Invalid time format"
      end
    else
      val
    end
  end

  def cast_boolean(val)
    if val.is_a?(String)
      val_lower = val.downcase.strip
      !["false", "0", "no", "off", "f", "n", ""].include?(val_lower)
    else
      ActiveModel::Type::Boolean.new.cast(val)
    end
  end

  def update_relationship(changes)
    @relationship.update!(changes)
  rescue ActiveRecord::RecordInvalid => e
    raise ValidationError, "Validation failed"
  end
end
