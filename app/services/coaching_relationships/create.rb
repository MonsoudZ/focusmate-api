# frozen_string_literal: true

module CoachingRelationships
  class Create
    def self.call!(current_user:, params:)
      CoachingRelationshipCreationService
        .new(current_user: current_user, params: params)
        .create!
    end
  end
end
