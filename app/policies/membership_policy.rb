class MembershipPolicy < ApplicationPolicy
  def index?
    # Can view memberships if user can view the list
    record.list.can_view?(user)
  end

  def show?
    # Can view membership if user can view the list
    record.list.can_view?(user)
  end

  def create?
    # Can invite members if user can invite to the list
    record.list.can_invite?(user)
  end

  def update?
    # Can update membership if user can invite to the list
    record.list.can_invite?(user)
  end

  def destroy?
    # Can remove members if user can invite to the list
    # OR if the membership belongs to the current user (self-removal)
    record.list.can_invite?(user) || record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see memberships for lists they have access to
      scope.joins(:list).where(list: List.accessible_by(user))
    end
  end
end
