# frozen_string_literal: true

class UserPreferencesService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = [])
      super(message)
      @details = details
    end
  end

  def initialize(user:, preferences:)
    @user = user
    @preferences = preferences
  end

  def update!
    validate_preferences!

    sanitized_preferences = sanitize_preferences(@preferences)

    if @user.update(preferences: sanitized_preferences)
      @user
    else
      Rails.logger.error "Preferences update failed: #{@user.errors.full_messages}"
      raise ValidationError.new("Failed to update preferences", @user.errors.full_messages)
    end
  end

  private

  def validate_preferences!
    unless @preferences.is_a?(Hash) || @preferences.is_a?(ActionController::Parameters)
      raise ValidationError.new("Preferences must be a valid object", [])
    end
  end

  def sanitize_preferences(preferences)
    # Recursively sanitize preferences to prevent malicious data
    case preferences
    when Hash
      preferences.transform_values { |v| sanitize_preferences(v) }
    when ActionController::Parameters
      # Convert to hash first, then sanitize
      preferences.permit!.to_h.transform_values { |v| sanitize_preferences(v) }
    when Array
      preferences.map { |v| sanitize_preferences(v) }
    when String
      # Limit string length but be more permissive for testing
      sanitized = preferences.to_s.strip
      sanitized.length > 5000 ? sanitized[0...5000] : sanitized
    when Numeric
      preferences
    when TrueClass, FalseClass
      preferences
    when NilClass
      nil
    else
      # Convert other types to string and sanitize
      sanitize_preferences(preferences.to_s)
    end
  end
end
