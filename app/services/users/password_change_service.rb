# frozen_string_literal: true

module Users
  class PasswordChangeService
    def self.call!(user:, current_password:, password:, password_confirmation:)
      new(
        user:,
        current_password:,
        password:,
        password_confirmation:
      ).call!
    end

    def initialize(user:, current_password:, password:, password_confirmation:)
      @user = user
      @current_password = current_password
      @password = password
      @password_confirmation = password_confirmation
    end

    def call!
      validate_not_apple_user!
      validate_current_password!
      validate_new_password!

      @user.update!(password: @password, password_confirmation: @password_confirmation)
      @user
    end

    private

    def validate_not_apple_user!
      return if @user.apple_user_id.blank?

      raise ApplicationError::Forbidden.new("Password change not available for Apple Sign In accounts", code: "password_change_forbidden")
    end

    def validate_current_password!
      return if @user.valid_password?(@current_password)

      raise ApplicationError::Validation.new("Current password is incorrect", details: { current_password: [ "is incorrect" ] })
    end

    def validate_new_password!
      if @password.blank?
        raise ApplicationError::Validation.new("Password is required", details: { password: [ "can't be blank" ] })
      end

      if @password.length < 8
        raise ApplicationError::Validation.new("Password too short", details: { password: [ "must be at least 8 characters" ] })
      end

      if @password != @password_confirmation
        raise ApplicationError::Validation.new("Password confirmation doesn't match", details: { password_confirmation: [ "doesn't match" ] })
      end
    end
  end
end
