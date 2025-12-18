# frozen_string_literal: true

class UserSerializer
  def self.one(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      timezone: user.timezone
    }
  end
end
