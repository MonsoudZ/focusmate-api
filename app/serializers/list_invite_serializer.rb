# frozen_string_literal: true

class ListInviteSerializer
  def initialize(invite)
    @invite = invite
  end

  def as_json
    {
      id: @invite.id,
      code: @invite.code,
      role: @invite.role,
      invite_url: @invite.invite_url,
      expires_at: @invite.expires_at,
      max_uses: @invite.max_uses,
      uses_count: @invite.uses_count,
      usable: @invite.usable?,
      created_at: @invite.created_at
    }
  end

  # Preview for unauthenticated users (less info)
  def as_preview_json
    {
      code: @invite.code,
      role: @invite.role,
      list: {
        id: @invite.list.id,
        name: @invite.list.name,
        color: @invite.list.color
      },
      inviter: {
        name: @invite.inviter.name
      },
      usable: @invite.usable?,
      expired: @invite.expired?,
      exhausted: @invite.exhausted?
    }
  end
end
