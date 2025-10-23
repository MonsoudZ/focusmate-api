class TaskPolicy < ApplicationPolicy
  def show?
    return false unless record
    record.visible_to?(user)
  end

  def create?
    return false unless user
    return false unless record
    # User can create tasks in lists they have access to
    record.list.accessible_by?(user) && record.list.can_add_items_by?(user)
  end

  def update?
    return false unless user
    return false unless record
    # User can update tasks they can see and have edit permissions for
    # But coaches cannot edit client's tasks
    if user.coach? && record.creator != user && record.list.owner != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def destroy?
    return false unless user
    return false unless record
    # User can delete tasks they can see and have delete permissions for
    # But coaches cannot delete client's tasks
    if user.coach? && record.creator != user && record.list.owner != user
      return false
    end
    record.visible_to?(user) && record.list.can_delete_items_by?(user)
  end

  def complete?
    return false unless user
    return false unless record
    # User can complete tasks they can see and have edit permissions for
    # But coaches cannot complete client's tasks
    if user.coach? && record.creator != user && record.list.owner != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def reassign?
    return false unless user
    return false unless record
    # User can reassign tasks they can see and have edit permissions for
    # But coaches cannot reassign client's tasks
    if user.coach? && record.creator != user && record.list.owner != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def change_visibility?
    return false unless user
    return false unless record
    # User can change visibility if they can change it
    record.can_change_visibility?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # For now, just return tasks in lists owned by the user
      scope.joins(:list).where(lists: { user_id: user.id })
    end
  end
end
