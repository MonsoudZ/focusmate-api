# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Only return memberships for lists the user can access
      # User can access a list if they own it OR are a member of it
      accessible_list_ids = List
                              .left_outer_joins(:memberships)
                              .where("lists.user_id = :uid OR memberships.user_id = :uid", uid: user.id)
                              .where(deleted_at: nil)
                              .select(:id)

      scope.where(list_id: accessible_list_ids)
    end
  end

  def index?
    true
  end

  def show?
    user_can_access_list?
  end

  def create?
    user_owns_list?
  end

  def update?
    user_owns_list?
  end

  def destroy?
    user_owns_list?
  end

  private

  def user_owns_list?
    record.list.user_id == user.id
  end

  def user_can_access_list?
    return true if record.list.user_id == user.id

    # Check if memberships are already loaded to avoid N+1 queries
    if record.list.memberships.loaded?
      record.list.memberships.any? { |m| m.user_id == user.id }
    else
      record.list.memberships.exists?(user_id: user.id)
    end
  end
end
