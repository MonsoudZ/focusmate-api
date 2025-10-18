class TaskPolicy < ApplicationPolicy
  def show?
    task.visible_to?(user)
  end

  def create?
    return false unless user
    # User can create tasks in lists they have access to
    task.list.accessible_by?(user) && task.list.can_add_items_by?(user)
  end

  def update?
    return false unless user
    # User can update tasks they can see and have edit permissions for
    task.visible_to?(user) && task.list.can_edit?(user)
  end

  def destroy?
    return false unless user
    # User can delete tasks they can see and have delete permissions for
    task.visible_to?(user) && task.list.can_delete_items_by?(user)
  end

  def complete?
    return false unless user
    # User can complete tasks they can see and have edit permissions for
    task.visible_to?(user) && task.list.can_edit?(user)
  end

  def reassign?
    return false unless user
    # User can reassign tasks they can see and have edit permissions for
    task.visible_to?(user) && task.list.can_edit?(user)
  end

  def change_visibility?
    return false unless user
    # User can change visibility if they can change it
    task.can_change_visibility?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Filter tasks based on user's visibility permissions
      scope.joins(:list).where(
        # Tasks in lists the user has access to
        list: List.accessible_by(user)
      ).where(
        # Tasks visible to the user based on visibility rules
        id: scope.select { |task| task.visible_to?(user) }.map(&:id)
      )
    end
  end
end
