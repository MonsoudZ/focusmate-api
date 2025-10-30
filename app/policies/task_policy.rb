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
    return false unless user
    return false unless record
    # User can update tasks they can see and have edit permissions for
    # But coaches cannot edit client's tasks
    if user.coach? && record.creator != user && record.list.user != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def destroy?
    return false unless user
    return false unless record
    # User can delete tasks they can see and have delete permissions for
    # But coaches cannot delete client's tasks
    if user.coach? && record.creator != user && record.list.user != user
      return false
    end
    record.visible_to?(user) && record.list.can_delete_items_by?(user)
  end

  def complete?
    return false unless user
    return false unless record
    # User can complete tasks they can see and have edit permissions for
    # But coaches cannot complete client's tasks
    if user.coach? && record.creator != user && record.list.user != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def reassign?
    return false unless user
    return false unless record
    # User can reassign tasks they can see and have edit permissions for
    # But coaches cannot reassign client's tasks
    if user.coach? && record.creator != user && record.list.user != user
      return false
    end
    record.visible_to?(user) && record.list.editable_by?(user)
  end

  def change_visibility?
    return false unless user
    return false unless record

    # Task creator can change visibility
    return true if record.creator == user

    # List owner can change visibility
    return true if record.list.user == user

    # Coach can change visibility of client's tasks
    if user.coach?
      # Check if there's a coaching relationship with the task creator or list owner
      return true if record.creator && user.clients.include?(record.creator)
      return true if record.list.user && user.clients.include?(record.list.user)
    end

    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Lists the user can see (owner_id OR user_id) OR accepted shares
      accessible_list_ids = List
        .left_outer_joins(:list_shares)
        .where(
          "lists.user_id = :uid " \
          "OR (list_shares.user_id = :uid AND list_shares.status = 'accepted')",
          uid: user.id
        )
        .select(:id)

      rel = scope.where("tasks.deleted_at IS NULL")
                 .where("tasks.list_id IN (?)", accessible_list_ids)
                 .includes(:list) # avoid N+1 when visible_to? looks at list

      # visible_to? is complex; keep it in Ruby
      rel.select { |task| task.visible_to?(user) }
    end
  end
end
