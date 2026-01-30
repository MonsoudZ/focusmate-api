# frozen_string_literal: true

module Auth
  class Login
    class Unauthorized < ApplicationError::Unauthorized
      def default_code = "login_unauthorized"
    end
    class BadRequest < ApplicationError::BadRequest; end

    def self.call!(email:, password:)
      new(email:, password:).call!
    end

    def initialize(email:, password:)
      @email = email.to_s.strip.downcase
      @password = password.to_s
    end

    def call!
      raise BadRequest, "Email and password are required" if @email.blank? || @password.blank?

      user = User.find_by(email: @email)

      # Always return a generic error (avoid user enumeration)
      unless user&.valid_password?(@password)
        raise Unauthorized, "Invalid email or password"
      end

      user
    end
  end
end
