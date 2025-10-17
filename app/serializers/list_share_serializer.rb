class ListShareSerializer
  attr_reader :share

  def initialize(share)
    @share = share
  end

  def as_json
    {
      id: share.id,
      list: {
        id: share.list.id,
        name: share.list.name
      },
      coach: UserSerializer.new(share.user).as_json,
      can_add_items: share.can_add_items,
      receive_overdue_alerts: share.receive_overdue_alerts,
      created_at: share.created_at.iso8601
    }
  end
end
