# frozen_string_literal: true

module Auth
  class Login
    def self.call!(email:, password:)
      new(email:, password:).call!
    end

    def initialize(email:, password:)
      @email = email.to_s.strip.downcase
      @password = password.to_s
    end

    def call!
      raise ApplicationError::BadRequest, "Email and password are required" if @email.blank? || @password.blank?

      user = User.find_by(email: @email)

      # Always return a generic error (avoid user enumeration)
      unless user&.valid_password?(@password)
        raise ApplicationError::Unauthorized.new("Invalid email or password", code: "login_unauthorized")
      end

      user
    end
  end
end
