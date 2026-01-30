# frozen_string_literal: true

module Auth
  class Register
    def self.call!(email:, password:, password_confirmation:, name: nil, timezone: nil)
      new(
        email:,
        password:,
        password_confirmation:,
        name:,
        timezone:
      ).call!
    end

    def initialize(email:, password:, password_confirmation:, name:, timezone:)
      @attrs = {
        email: email.to_s.strip.downcase,
        password: password,
        password_confirmation: password_confirmation,
        name: name,
        timezone: timezone
      }
    end

    def call!
      raise ApplicationError::BadRequest, "Email is required" if @attrs[:email].blank?
      raise ApplicationError::BadRequest, "Password is required" if @attrs[:password].blank?

      user = User.new(@attrs)
      user.save!
      user
    end
  end
end
