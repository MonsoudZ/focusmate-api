module ListShares
  class Decline
    def self.call!(share:, actor:)
      ListShareDeclineService
        .new(list_share: share)
        .decline!
    end
  end
end