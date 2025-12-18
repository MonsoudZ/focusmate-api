# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # If you already authorized @list for show?, this scope just ensures
      # you can't see memberships for lists you don't have access to.
      scope.joins(:list).where(lists: { id: visible_list_ids })
    end

    private

    def visible_list_ids
      owned  = List.where(user_id: user.id).select(:id)
      List.where(id: owned).select(:id)
    end
  end
end
