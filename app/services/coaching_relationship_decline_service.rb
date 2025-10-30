# frozen_string_literal: true

class CoachingRelationshipDeclineService
  class UnauthorizedError < StandardError; end

  def initialize(relationship:, current_user:)
    @relationship = relationship
    @current_user = current_user
  end

  def decline!
    validate_can_decline!

    @relationship.update!(status: "declined")

    # Send notification asynchronously
    queue_notification("coaching_invitation_declined", @relationship.id)

    true
  end

  private

  def validate_can_decline!
    unless invitee?(@relationship, @current_user) && @relationship.status.to_s == "pending"
      raise UnauthorizedError, "You cannot decline this invitation"
    end
  end

  def invitee?(rel, user)
    rel.invited_by == "coach" ? (rel.client_id == user.id) : (rel.coach_id == user.id)
  end

  def queue_notification(event, relationship_id)
    NotificationJob.perform_later(event, relationship_id)
  rescue => e
    Rails.logger.error "[CoachingRelationshipDeclineService] Error queueing notification: #{e.message}"
  end
end
