# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def show?
    return false unless record

    if record.respond_to?(:status) && record.status.to_s == "deleted"
      return false unless user
      return record.list.user_id == user.id
    end

    record.visible_to?(user)
  end

  def create?
    return false unless user && record
    record.list.accessible_by?(user) && record.list.can_edit?(user)
  end

  def update?
    can_mutate? && record.list.can_edit?(user)
  end

  def destroy?
    can_mutate? && record.list.can_edit?(user)
  end

  def complete?
    can_mutate? && record.list.can_edit?(user)
  end

  def reassign?
    can_mutate? && record.list.can_edit?(user)
  end

  private

  def can_mutate?
    return false unless user && record
    record.visible_to?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      accessible_list_ids = List
                              .left_outer_joins(:memberships)
                              .where("lists.user_id = :uid OR memberships.user_id = :uid", uid: user.id)
                              .select(:id)

      scope.where(deleted_at: nil)
           .where(list_id: accessible_list_ids)
           .includes(:list)
           .select { |task| task.visible_to?(user) }
    end
  end
end
