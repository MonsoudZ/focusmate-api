# frozen_string_literal: true

class ListPolicy < ApplicationPolicy
  def show?
    owner? || accepted_share?
  end

  # OWNER ONLY
  def manage_memberships?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
  def manage_shares?
    owner?
  end
end
