# frozen_string_literal: true

module CoachingRelationships
  class Query
    def self.call!(user:, status: nil)
      scope =
        if user.coach?
          user.coaching_relationships_as_coach.includes(:client)
        else
          user.coaching_relationships_as_client.includes(:coach)
        end

      status.present? ? scope.where(status: status) : scope
    end
  end
end
