module ListShares
  class Accept
    def self.call!(share:, actor:, token:)
      ListShareAcceptanceService
        .new(list_share: share, current_user: actor)
        .accept!(invitation_token: token)
    end

    def self.accept_by_token!(token:)
      ListShareAcceptanceService.accept_by_token!(token: token)
    end
  end
end