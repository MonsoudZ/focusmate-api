class UserSerializer
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def as_json
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      timezone: user.timezone,
      created_at: user.created_at.iso8601
    }
  end
end
