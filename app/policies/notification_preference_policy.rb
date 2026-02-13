# frozen_string_literal: true

class NotificationPreferencePolicy < ApplicationPolicy
  def show?
    owner?
  end

  def create?
    true
  end

  def update?
    owner?
  end

  private

  def owner?
    record.user_id == user.id
  end
end
