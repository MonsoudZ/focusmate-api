# frozen_string_literal: true

class StreakUpdateJob < ApplicationJob
  queue_as :low

  def perform(user_id:)
    user = User.find_by(id: user_id)
    return unless user

    StreakService.new(user).update_streak!
  end
end
