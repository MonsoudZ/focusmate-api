# app/serializers/membership_serializer.rb
# frozen_string_literal: true

class MembershipSerializer
  def self.one(membership)
    { membership: serialize(membership) }
  end

  def self.collection(memberships)
    { memberships: memberships.map { |m| serialize(m) } }
  end

  def self.serialize(m)
    {
      id: m.id,
      user: {
        id: m.user_id,
        email: m.user&.email,
        name: m.user&.name
      },
      role: m.role,
      created_at: m.created_at,
      updated_at: m.updated_at
    }
  end

  private_class_method :serialize
end