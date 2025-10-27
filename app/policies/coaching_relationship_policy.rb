# frozen_string_literal: true

class CoachingRelationshipPolicy
  def initialize(user, relationship)
    @user = user
    @rel = relationship
  end

  def request?
    @user.id == @rel.client_id
  end

  def accept?
    @user.id == @rel.coach_id && @rel.pending?
  end

  def decline?
    accept?
  end

  def cancel?
    @user.id == @rel.client_id && @rel.pending?
  end

  def terminate?
    (@user.id == @rel.client_id || @user.id == @rel.coach_id) && @rel.active?
  end
end
