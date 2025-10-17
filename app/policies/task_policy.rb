class TaskPolicy < ApplicationPolicy
  def index?
    # Can view tasks if user can view the list
    record.list.can_view?(user)
  end

  def show?
    # Can view task if user can view the list
    record.list.can_view?(user)
  end

  def create?
    # Can create tasks if user can edit the list
    record.list.can_edit?(user)
  end

  def update?
    # Can update tasks if user can edit the list
    record.list.can_edit?(user)
  end

  def destroy?
    # Can delete tasks if user can edit the list
    record.list.can_edit?(user)
  end

  def complete?
    # Can complete tasks if user can edit the list
    record.list.can_edit?(user)
  end

  def reassign?
    # Can reassign tasks if user can edit the list AND task allows reassignment
    record.list.can_edit?(user) && record.can_be_reassigned_by?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see tasks for lists they have access to
      scope.joins(:list).where(list: List.accessible_by(user))
    end
  end
end
