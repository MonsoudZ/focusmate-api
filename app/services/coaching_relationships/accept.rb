# frozen_string_literal: true

module CoachingRelationships
  class Accept
    def self.call!(relationship:, actor:)
      CoachingRelationshipAcceptanceService
        .new(relationship: relationship, current_user: actor)
        .accept!
    end
  end
end
