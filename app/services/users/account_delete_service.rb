# frozen_string_literal: true

module Users
  class AccountDeleteService
    class ValidationError < ApplicationError::Validation; end

    def self.call!(user:, password: nil)
      new(user:, password:).call!
    end

    def initialize(user:, password:)
      @user = user
      @password = password
    end

    def call!
      validate_password_if_required!

      @user.destroy!
    end

    private

    def validate_password_if_required!
      # Apple Sign In users don't need password confirmation
      return if @user.apple_user_id.present?

      # Email users must confirm with password
      return if @password.present? && @user.valid_password?(@password)

      raise ValidationError.new("Password is incorrect", details: { password: [ "is incorrect" ] })
    end
  end
end
