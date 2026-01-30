# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  def show?
    permissions.can_view?
  end

  def create?
    return false unless user && record
    return false unless record.list

    Permissions::ListPermissions.can_edit?(record.list, user)
  end

  def update?
    permissions.can_edit?
  end

  def destroy?
    permissions.can_delete?
  end

  def nudge?
    permissions.can_nudge?
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

  private

  def permissions
    @permissions ||= Permissions::TaskPermissions.new(record, user)
  end
end
