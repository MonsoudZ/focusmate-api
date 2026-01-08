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
    owner? || member?
  end

  def create?
    true
  end

  def update?
    owner? || editor?
  end

  def destroy?
    owner?
  end

  def manage_memberships?
    owner?
  end

  def create_task?
    record.can_edit?(user)
  end

  private

  def owner?
    record.user_id == user.id
  end

  def member?
    record.memberships.exists?(user_id: user.id)
  end

  def editor?
    record.memberships.exists?(user_id: user.id, role: "editor")
  end
end
