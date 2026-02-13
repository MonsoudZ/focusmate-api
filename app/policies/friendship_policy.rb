# frozen_string_literal: true

class FriendshipPolicy < ApplicationPolicy
  # Headless policy — controller passes :friendship as the record.
  # Actions require an authenticated user; the controller further scopes
  # queries through current_user.friends.

  def index?
    user.present?
  end

  def destroy?
    user.present?
  end
end
