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

  def accepted_share?
    ListShare.exists?(list_id: record.id, user_id: user.id, status: "accepted")
  end
  def manage_shares?
    owner?
  end

end
