# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def show?
    return false unless user && record
    return false if record.deleted?
    return false unless record.list
    record.list.accessible_by?(user)
  end

  def create?
    return false unless user && record
    return false unless record.list
    record.list.can_edit?(user)
  end

  def update?
    return false unless user && record
    return false if record.deleted?
    return false unless record.list
    record.list.can_edit?(user)
  end

  def destroy?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      list_ids = List
                   .left_outer_joins(:memberships)
                   .where("lists.user_id = :uid OR memberships.user_id = :uid", uid: user.id)
                   .where(deleted_at: nil)
                   .select(:id)

      scope.where(deleted_at: nil)
           .where(list_id: list_ids)
    end
  end
end
