# frozen_string_literal: true

class UserSerializer
  def self.one(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      timezone: user.timezone,
      has_password: user.apple_user_id.blank?
    }
  end
end