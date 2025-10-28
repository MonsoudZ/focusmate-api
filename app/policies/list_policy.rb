class ListPolicy < ApplicationPolicy
  def index?
    true # Any authenticated user can see lists they have access to
  end

  def show?
    record.can_view?(user)
  end

  def create?
    true # Any authenticated user can create lists
  end

  def update?
    record.can_edit?(user)
  end

  def destroy?
    record.user == user # Only the user can delete a list
  end

  def invite_member?
    record.can_invite?(user)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see lists they own or are members of
      scope.accessible_by(user)
    end
  end
end
