# frozen_string_literal: true

class CoachingRelationshipAcceptanceService
  class UnauthorizedError < StandardError; end

  def initialize(relationship:, current_user:)
    @relationship = relationship
    @current_user = current_user
  end

  def accept!
    validate_can_accept!

    @relationship.update!(status: "active", accepted_at: Time.current)

    # Reload with associations
    @relationship = CoachingRelationship.includes(:coach, :client).find(@relationship.id)

    # Send notification asynchronously
    queue_notification("coaching_invitation_accepted", @relationship.id)

    @relationship
  end

  private

  def validate_can_accept!
    unless invitee?(@relationship, @current_user) && @relationship.status.to_s == "pending"
      raise UnauthorizedError, "You cannot accept this invitation"
    end
  end

  def invitee?(rel, user)
    rel.invited_by == "coach" ? (rel.client_id == user.id) : (rel.coach_id == user.id)
  end

  def queue_notification(event, relationship_id)
    NotificationJob.perform_later(event, relationship_id)
  rescue => e
    Rails.logger.error "[CoachingRelationshipAcceptanceService] Error queueing notification: #{e.message}"
  end
end
