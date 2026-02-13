# app/serializers/membership_serializer.rb
# frozen_string_literal: true

class MembershipSerializer
  def initialize(membership)
    @membership = membership
  end

  def as_json
    {
      id: @membership.id,
      user: {
        id: @membership.user_id,
        name: @membership.user&.name
      },
      role: @membership.role,
      created_at: @membership.created_at,
      updated_at: @membership.updated_at
    }
  end
end
