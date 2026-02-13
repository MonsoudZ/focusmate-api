# frozen_string_literal: true

class FriendshipPolicy < ApplicationPolicy
  # Headless policy — controller passes :friendship as the record.
  # All actions are safe because FriendsController already scopes
  # queries through current_user.friends.

  def index?
    true
  end

  def destroy?
    true
  end
end
