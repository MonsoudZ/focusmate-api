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
      member_list_ids = Membership.where(user_id: user.id).select(:list_id)
      accessible_list_ids = List.where(user_id: user.id).or(List.where(id: member_list_ids)).select(:id)

      scope.where(list_id: accessible_list_ids)
           .visible_to_user(user)
    end
  end

  private

  def permissions
    @permissions ||= Permissions::TaskPermissions.new(record, user)
  end
end
