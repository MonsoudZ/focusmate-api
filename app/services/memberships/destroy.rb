# frozen_string_literal: true

module Memberships
  class Destroy
    class Error < StandardError; end
    class Conflict < Error; end

    def self.call!(membership:, actor:)
      # owner should never remove themselves from their own list
      if membership.list.user_id.present? && membership.list.user_id == membership.user_id
        raise Conflict, "Cannot remove the list owner"
      end

      membership.destroy!
    end
  end
end
