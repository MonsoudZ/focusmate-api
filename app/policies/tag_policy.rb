# frozen_string_literal: true

# TagPolicy handles authorization for Tag resources.
#
# Tags are user-owned - only the creator can view/edit/delete their tags.
#
class TagPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      # Users can only see their own tags
      scope.where(user_id: user.id)
    end
  end

  def index?
    true
  end

  def show?
    owner?
  end

  def create?
    true
  end

  def update?
    owner?
  end

  def destroy?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
