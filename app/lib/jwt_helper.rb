# frozen_string_literal: true

class JwtHelper
  # JWT token expiration time in hours (default: 24 hours)
  # Can be configured via JWT_EXPIRATION_HOURS environment variable
  JWT_EXPIRATION_HOURS = ENV.fetch("JWT_EXPIRATION_HOURS", "24").to_i

  def self.access_for(user)
    payload = {
      user_id: user.id,
      exp: JWT_EXPIRATION_HOURS.hours.from_now.to_i,
      iat: Time.current.to_i,
      jti: user.jti # Include JTI for token revocation support
    }

    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end
end
