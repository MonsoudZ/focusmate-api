# frozen_string_literal: true

class UserDeviceTokenService
  class ValidationError < StandardError; end

  def initialize(user:, token:, token_type: :device)
    @user = user
    @token = token
    @token_type = token_type # :device or :fcm
  end

  def update!
    validate_token!

    attribute = @token_type == :fcm ? :fcm_token : :device_token

    if @user.update(attribute => @token)
      log_success
      @user
    else
      raise ValidationError, "Failed to update #{@token_type} token"
    end
  end

  private

  def validate_token!
    # Reject empty or whitespace-only tokens (but allow nil for logout)
    if @token && @token.strip.blank?
      raise ValidationError, "#{token_label} is required"
    end
  end

  def token_label
    @token_type == :fcm ? "FCM token" : "Device token"
  end

  def log_success
    token_preview = TokenHelper.redact_token(@token)
    Rails.logger.info "[#{token_label}] Updated for user ##{@user.id}: #{token_preview}"
  end
end
