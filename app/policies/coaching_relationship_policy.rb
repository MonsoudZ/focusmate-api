# frozen_string_literal: true

class CoachingRelationshipPolicy < ApplicationPolicy
  def show?
    participant?
  end

  def accept?
    participant?
  end

  def decline?
    participant?
  end

  def update_preferences?
    participant?
  end

  def destroy?
    participant?
  end

  private

  def participant?
    record.coach_id == user.id || record.client_id == user.id
  end
end
