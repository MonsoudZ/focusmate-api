# frozen_string_literal: true

class UserLocationUpdateService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = [])
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
    validate_coordinates!

    lat_f = @latitude.to_f
    lng_f = @longitude.to_f

    Rails.logger.info "Updating location for user #{@user.id}: lat=#{lat_f}, lng=#{lng_f}"

    ActiveRecord::Base.transaction do
      update_user_location(lat_f, lng_f)
      create_location_history(lat_f, lng_f)
      @user.reload
    end

    Rails.logger.info "Location updated successfully: lat=#{@user.latitude}, lng=#{@user.longitude}"
    @user
  end

  private

  def validate_coordinates!
    if @latitude.blank? || @longitude.blank?
      raise ValidationError.new("Latitude and longitude are required", [])
    end
  end

  def update_user_location(lat_f, lng_f)
    unless @user.update(
      latitude: lat_f,
      longitude: lng_f,
      location_updated_at: Time.current
    )
      Rails.logger.error "Failed to update location: #{@user.errors.full_messages}"
      raise ValidationError.new("Failed to update location", @user.errors.full_messages)
    end
  end

  def create_location_history(lat_f, lng_f)
    @user.user_locations.create!(
      latitude: lat_f,
      longitude: lng_f,
      recorded_at: Time.current
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Location history creation failed: #{e.record.errors.full_messages}"
    raise ValidationError.new("Failed to update location", e.record.errors.full_messages)
  end
end
