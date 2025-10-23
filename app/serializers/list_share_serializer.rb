class ListShareSerializer
  attr_reader :list_share

  def initialize(list_share)
    @list_share = list_share
  end

  def as_json
    {
      id: list_share.id,
      list_id: list_share.list_id,
      email: list_share.email,
      role: list_share.role,
      status: list_share.status,
      invitation_token: list_share.invitation_token,
      can_view: list_share.can_view?,
      can_edit: list_share.can_edit?,
      can_add_items: list_share.can_add_items?,
      can_delete_items: list_share.can_delete_items?,
      receive_notifications: list_share.receive_notifications?,
      user_id: list_share.user_id,
      user: list_share.user ? {
        id: list_share.user.id,
        email: list_share.user.email,
        name: list_share.user.name || list_share.user.email.split("@").first,
        role: list_share.user.role
      } : nil,
      invited_at: list_share.invited_at&.iso8601,
      accepted_at: list_share.accepted_at&.iso8601,
      created_at: list_share.created_at.iso8601,
      updated_at: list_share.updated_at.iso8601
    }
  end
end
