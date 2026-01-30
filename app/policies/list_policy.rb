# frozen_string_literal: true

class ListPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      member_list_ids = Membership.where(user_id: user.id).select(:list_id)
      scope.where(user_id: user.id).or(scope.where(id: member_list_ids))
    end
  end

  def index?
    true
  end

  def show?
    permissions.can_view?
  end

  def create?
    true
  end

  def update?
    permissions.can_edit?
  end

  def destroy?
    permissions.can_delete?
  end

  def manage_memberships?
    permissions.can_manage_memberships?
  end

  def create_task?
    permissions.can_edit?
  end

  private

  def permissions
    @permissions ||= Permissions::ListPermissions.new(record, user)
  end
end
