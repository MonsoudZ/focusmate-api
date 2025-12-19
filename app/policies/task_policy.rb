class TaskPolicy < ApplicationPolicy
  def show?
    return false unless record

    # If deleted, only the list owner may view
    if record.respond_to?(:status) && record.status.to_s == "deleted"
      return false unless user
      list_owner_id = record.list.user_id
      return list_owner_id == user.id
    end

    record.visible_to?(user)
  end

  def create?
    return false unless user
    return false unless record
    # User can create tasks in lists they have access to
    record.list.accessible_by?(user) && record.list.can_add_items_by?(user)
  end

  def update?
    can_mutate? && record.list.editable_by?(user)
  end

  def destroy?
    can_mutate? && record.list.can_delete_items_by?(user)
  end

  def complete?
    can_mutate? && record.list.editable_by?(user)
  end

  def reassign?
    can_mutate? && record.list.editable_by?(user)
  end

  def change_visibility?
    return false unless user && record
    # Only task creator or list owner can change visibility
    record.creator == user || record.list.user == user
  end

  private

  def can_mutate?
    return false unless user && record
    return false if coach_blocked?
    record.visible_to?(user)
  end

  def coach_blocked?
    user.coach? && record.creator != user && record.list.user != user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Lists the user owns or is a member of
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
