# frozen_string_literal: true

class UserPreferencesService
  class ValidationError < StandardError
    attr_reader :details

    def initialize(message, details: {})
      super(message)
      @details = details
    end
  end

  def initialize(user:, preferences:)
    @user = user
    @preferences = preferences
  end

  def update!
    prefs_hash = coerce_hash!(@preferences)
    sanitized = sanitize_preferences(prefs_hash)

    if @user.update(preferences: sanitized)
      @user
    else
      raise ValidationError.new(
        "Failed to update preferences",
        details: { preferences: Array(@user.errors.full_messages) }
      )
    end
  end

  private

  def coerce_hash!(value)
    case value
    when ActionController::Parameters
      # In API controllers you’ll commonly receive this shape
      value.permit!.to_h
    when Hash
      value
    else
      raise ValidationError.new(
        "Preferences must be a JSON object",
        details: { preferences: [ "must_be_object" ] }
      )
    end
  end

  def sanitize_preferences(value)
    case value
    when Hash
      value.transform_values { |v| sanitize_preferences(v) }
    when Array
      value.map { |v| sanitize_preferences(v) }
    when String
      s = value.strip
      s.length > 5000 ? s[0...5000] : s
    when Numeric, TrueClass, FalseClass, NilClass
      value
    else
      # Don’t let weird objects leak into JSON
      sanitize_preferences(value.to_s)
    end
  end
end
