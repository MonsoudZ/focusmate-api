# frozen_string_literal: true

module JwtHelpers
  def jwt_for(user)
    # Warden::JWTAuth is provided by devise-jwt
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  def auth_headers(user, extra: {})
    token = jwt_for(user)
    {
      "Authorization" => "Bearer #{token}",
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }.merge(extra)
  end
end
