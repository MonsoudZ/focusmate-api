# frozen_string_literal: true

module Users
  class PasswordChangeService
    class Error < StandardError; end
    class Forbidden < Error; end
    class ValidationError < Error
      attr_reader :details

      def initialize(message, details = {})
        super(message)
        @details = details
      end
    end

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

      @user.update!(password: @password)
      @user
    end

    private

    def validate_not_apple_user!
      return if @user.apple_user_id.blank?

      raise Forbidden, "Password change not available for Apple Sign In accounts"
    end

    def validate_current_password!
      return if @user.valid_password?(@current_password)

      raise ValidationError.new("Current password is incorrect", { current_password: [ "is incorrect" ] })
    end

    def validate_new_password!
      if @password.blank?
        raise ValidationError.new("Password is required", { password: [ "can't be blank" ] })
      end

      if @password.length < 6
        raise ValidationError.new("Password too short", { password: [ "must be at least 6 characters" ] })
      end

      if @password != @password_confirmation
        raise ValidationError.new("Password confirmation doesn't match", { password_confirmation: [ "doesn't match" ] })
      end
    end
  end
end
