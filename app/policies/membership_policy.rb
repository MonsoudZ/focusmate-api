# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def index?
    true
  end

  def show?
    true
  end

  def create?
    record.list.user_id == user.id
  end

  def update?
    record.list.user_id == user.id
  end

  def destroy?
    record.list.user_id == user.id
  end
end