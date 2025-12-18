# frozen_string_literal: true

class UserLocationUpdateService
  class ValidationError < StandardError
    attr_reader :details

    def initialize(message, details: {})
      super(message)
      @details = details
    end
  end

  def initialize(user:, latitude:, longitude:)
    @user = user
    @latitude = latitude
    @longitude = longitude
  end

  def update!
    lat = parse_coordinate!(@latitude, field: :latitude, min: -90.0, max: 90.0)
    lng = parse_coordinate!(@longitude, field: :longitude, min: -180.0, max: 180.0)

    ActiveRecord::Base.transaction do
      @user.update!(
        latitude: lat,
        longitude: lng,
        location_updated_at: Time.current
      )

      # Keep history in sync with the user row
      @user.user_locations.create!(
        latitude: lat,
        longitude: lng,
        recorded_at: Time.current
      )
    end

    @user.reload
  rescue ActiveRecord::RecordInvalid => e
    # Could be user update or location create
    raise ValidationError.new(
      "Failed to update location",
      details: e.record.errors.to_hash
    )
  end

  private

  def parse_coordinate!(value, field:, min:, max:)
    if value.nil? || value.to_s.strip.empty?
      raise ValidationError.new(
        "#{field.to_s.humanize} is required",
        details: { field => ["required"] }
      )
    end

    num = Float(value)
    unless num >= min && num <= max
      raise ValidationError.new(
        "#{field.to_s.humanize} is out of range",
        details: { field => ["must_be_between_#{min}_and_#{max}"] }
      )
    end

    num
  rescue ArgumentError, TypeError
    raise ValidationError.new(
      "#{field.to_s.humanize} must be a number",
      details: { field => ["not_a_number"] }
    )
  end
end
