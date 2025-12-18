# frozen_string_literal: true

class CoachingRelationshipSerializer
  def self.one(relationship)
    { coaching_relationship: serialize(relationship) }
  end

  def self.collection(relationships)
    {
      coaching_relationships: relationships.map { |r| serialize(r) }
    }
  end

  def self.preferences(relationship)
    {
      id: relationship.id,
      notify_on_completion: relationship.notify_on_completion,
      notify_on_missed_deadline: relationship.notify_on_missed_deadline,
      send_daily_summary: relationship.send_daily_summary,
      daily_summary_time: relationship.daily_summary_time&.strftime("%H:%M")
    }
  end

  def self.serialize(r)
    {
      id: r.id,
      coach_id: r.coach_id,
      client_id: r.client_id,
      status: r.status,
      invited_by: r.invited_by,
      accepted_at: r.accepted_at&.iso8601,
      coach: serialize_user(r.coach),
      client: serialize_user(r.client)
    }
  end

  def self.serialize_user(user)
    return nil unless user

    {
      id: user.id,
      email: user.email,
      name: user.name
    }
  end

  private_class_method :serialize, :serialize_user
end
