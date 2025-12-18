# frozen_string_literal: true

module CoachingRelationships
  class UpdatePreferences
    def self.call!(relationship:, actor:, params:)
      CoachingRelationshipPreferencesService
        .new(
          relationship: relationship,
          current_user: actor,
          params: params
        )
        .update!
    end
  end
end
