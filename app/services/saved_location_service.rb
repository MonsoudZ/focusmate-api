# frozen_string_literal: true

class SavedLocationService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = [])
      super(message)
      @details = details
    end
  end

  def initialize(user:)
    @user = user
  end

  def create(params)
    # Validate parameter format
    param_errors = validate_params_format(params)

    # Build location and collect all errors
    location = @user.saved_locations.build(sanitize_params(params))

    if location.valid?
      location.save!
      Rails.logger.info "[SavedLocationService] Created location ##{location.id} for user ##{@user.id}"
      location
    else
      # Combine param format errors with model validation errors
      all_errors = param_errors + location.errors.full_messages
      Rails.logger.error "[SavedLocationService] Validation failed: #{all_errors}"
      raise ValidationError.new("Validation failed", all_errors.uniq)
    end
  end

  def update(location:, params:)
    validate_ownership!(location)

    # Validate parameter format
    param_errors = validate_params_format(params)

    # Try to update and collect all errors
    location.assign_attributes(sanitize_params(params))

    if location.valid?
      location.save!
      Rails.logger.info "[SavedLocationService] Updated location ##{location.id}"
      location
    else
      # Combine param format errors with model validation errors
      all_errors = param_errors + location.errors.full_messages
      Rails.logger.error "[SavedLocationService] Update validation failed: #{all_errors}"
      raise ValidationError.new("Validation failed", all_errors.uniq)
    end
  end

  def destroy(location:)
    validate_ownership!(location)

    location.destroy
    Rails.logger.info "[SavedLocationService] Deleted location ##{location.id}"
    true
  end

  private

  def validate_ownership!(location)
    unless location.user_id == @user.id
      raise ValidationError.new("Unauthorized", [ "You don't have permission to modify this location" ])
    end
  end

  def validate_params_format(params)
    errors = []

    # Validate latitude if present
    if params[:latitude].present?
      latitude = params[:latitude].to_f
      if latitude > 90
        errors << "Latitude must be less than or equal to 90"
      elsif latitude < -90
        errors << "Latitude must be greater than or equal to -90"
      end
    end

    # Validate longitude if present
    if params[:longitude].present?
      longitude = params[:longitude].to_f
      if longitude > 180
        errors << "Longitude must be less than or equal to 180"
      elsif longitude < -180
        errors << "Longitude must be greater than or equal to -180"
      end
    end

    # Validate radius_meters if present
    if params[:radius_meters].present?
      radius = params[:radius_meters].to_f
      if radius <= 0
        errors << "Radius meters must be greater than 0"
      elsif radius > 10000
        errors << "Radius meters must be less than or equal to 10000"
      end
    end

    # Validate name length if present
    if params[:name].present?
      name = params[:name].to_s
      if name.length > 255
        errors << "Name is too long (maximum is 255 characters)"
      end
    end

    # Validate address length if present
    if params[:address].present?
      address = params[:address].to_s
      if address.length > 500
        errors << "Address is too long (maximum is 500 characters)"
      end
    end

    errors
  end

  def sanitize_params(params)
    {
      name: params[:name]&.to_s&.strip,
      latitude: params[:latitude]&.to_f,
      longitude: params[:longitude]&.to_f,
      radius_meters: params[:radius_meters]&.to_f,
      address: params[:address]&.to_s&.strip
    }.compact
  end
end
