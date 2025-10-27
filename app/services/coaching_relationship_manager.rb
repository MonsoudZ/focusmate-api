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
    # For now, we'll use a simple notification service
    # In a real app, you'd enqueue a job like: RelationshipEventJob.perform_later(@rel.id, event)
    Rails.logger.info "Coaching relationship event: #{event} for relationship #{@rel.id}"
  end
end
