# frozen_string_literal: true

class JwtHelper
  def self.access_for(user)
    payload = {
      user_id: user.id,
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i
    }

    JWT.encode(payload, Rails.application.secret_key_base, "HS256")
  end
end
