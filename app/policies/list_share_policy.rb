# frozen_string_literal: true

class ListSharePolicy < ApplicationPolicy
  def show?
    list_owner? || share_user?
  end

  def update?
    list_owner?
  end

  def update_permissions?
    list_owner?
  end

  def destroy?
    list_owner? || share_user?
  end

  def accept?
    share_user?
  end

  def decline?
    share_user?
  end

  class Scope < Scope
    def resolve
      scope.where(list_id: visible_list_ids)
    end

    private

    def visible_list_ids
      owned = List.where(user_id: user.id).select(:id)
      shared = ListShare.where(user_id: user.id, status: "accepted").select(:list_id)
      List.where(id: owned).or(List.where(id: shared)).select(:id)
    end
  end

  private

  def list_owner?
    record.list.user_id == user.id
  end

  def share_user?
    record.user_id == user.id
  end
end
