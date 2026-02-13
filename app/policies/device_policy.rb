# frozen_string_literal: true

class DevicePolicy < ApplicationPolicy
  def create?
    true
  end

  def destroy?
    record.user_id == user.id
  end
end
