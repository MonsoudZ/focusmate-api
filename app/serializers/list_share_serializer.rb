# frozen_string_literal: true

class ListShareSerializer
  def self.one(share)
    { share: serialize(share) }
  end

  def self.collection(shares, pagination = nil)
    payload = { shares: shares.map { |s| serialize(s) } }
    payload[:pagination] = pagination if pagination
    payload
  end

  def self.serialize(s)
    {
      id: s.id,
      email: s.email,
      role: s.role,
      status: s.status,
      user_id: s.user_id,
      permissions: {
        can_view: s.can_view,
        can_edit: s.can_edit,
        can_add_items: s.can_add_items,
        can_delete_items: s.can_delete_items,
        receive_notifications: s.receive_notifications
      },
      invited_at: s.invited_at,
      created_at: s.created_at,
      updated_at: s.updated_at
    }
  end

  private_class_method :serialize
end
