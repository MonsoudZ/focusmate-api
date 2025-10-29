# frozen_string_literal: true

class CoachingRelationshipManager
  def initialize(relationship, actor)
    @rel = relationship
    @actor = actor
  end

  def request!
    authorize!(:request?)
    @rel.update!(status: :pending)
    enqueue_notification(:relationship_requested)
    @rel
  end

  def accept!
    authorize!(:accept?)
    ApplicationRecord.transaction do
      @rel.update!(status: :active)
      enqueue_notification(:relationship_accepted)
    end
    @rel
  end

  def decline!
    authorize!(:decline?)
    @rel.update!(status: :declined).tap { enqueue_notification(:relationship_declined) }
  end

  def cancel!
    authorize!(:cancel?)
    @rel.update!(status: :inactive).tap { enqueue_notification(:relationship_cancelled) }
  end

  def terminate!
    authorize!(:terminate?)
    @rel.update!(status: :inactive).tap { enqueue_notification(:relationship_terminated) }
  end

  private

  def authorize!(action)
    policy = CoachingRelationshipPolicy.new(@actor, @rel)
    raise Pundit::NotAuthorizedError unless policy.public_send(action)
  end

  def enqueue_notification(event)
    # Map internal events to NotificationService methods
    method = case event
    when :relationship_requested then :coaching_invitation_sent
    when :relationship_accepted then :coaching_invitation_accepted
    when :relationship_declined then :coaching_invitation_declined
    when :relationship_cancelled then :coaching_invitation_declined
    when :relationship_terminated then :coaching_invitation_declined
    else
               Rails.logger.warn "Unknown coaching relationship event: #{event}"
               return
    end

    NotificationJob.perform_later(method.to_s, @rel.id)
  end
end
