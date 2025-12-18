# frozen_string_literal: true

module CoachingRelationships
  class Decline
    def self.call!(relationship:, actor:)
      CoachingRelationshipDeclineService
        .new(relationship: relationship, current_user: actor)
        .decline!
    end
  end
end
