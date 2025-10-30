# frozen_string_literal: true

class CoachingRelationshipCreationService
  class ValidationError < StandardError; end
  class NotFoundError < StandardError; end

  def initialize(current_user:, params:)
    @current_user = current_user
    @params = params
  end

  def create!
    coach_email = normalize_email(@params[:coach_email])
    client_email = normalize_email(@params[:client_email])
    invited_by = @params[:invited_by].presence

    validate_emails!(coach_email, client_email)

    coach, client, invited_by = determine_participants(coach_email, client_email, invited_by)

    validate_no_self_invitation!(coach, client)
    validate_no_existing_relationship!(coach, client)

    create_relationship(coach, client, invited_by)
  end

  private

  def normalize_email(email)
    email.to_s.strip.downcase.presence
  end

  def validate_emails!(coach_email, client_email)
    if coach_email.blank? && client_email.blank?
      raise ValidationError, "Must provide coach_email or client_email"
    end
  end

  def determine_participants(coach_email, client_email, invited_by)
    if invited_by == "coach" || (invited_by.blank? && client_email.present?)
      coach = @current_user
      client = find_user_by_email(client_email || coach_email)

      unless client
        raise NotFoundError, "Client not found with that email"
      end

      invited_by = "coach"
    else
      client = @current_user
      coach = find_user_by_email(coach_email || client_email)

      unless coach
        raise NotFoundError, "Coach not found with that email"
      end

      invited_by = "client"
    end

    [coach, client, invited_by]
  end

  def find_user_by_email(email)
    return nil if email.blank?
    User.where("LOWER(email) = ?", email.downcase).first
  end

  def validate_no_self_invitation!(coach, client)
    if coach.id == client.id
      raise ValidationError, "You cannot invite yourself"
    end
  end

  def validate_no_existing_relationship!(coach, client)
    if CoachingRelationship.exists?(coach_id: coach.id, client_id: client.id)
      raise ValidationError, "Relationship already exists"
    end
  end

  def create_relationship(coach, client, invited_by)
    rel = CoachingRelationship.create!(
      coach: coach,
      client: client,
      invited_by: invited_by,
      status: "pending"
    )

    # Reload with associations
    rel = CoachingRelationship.includes(:coach, :client).find(rel.id)

    # Send notification asynchronously
    queue_notification("coaching_invitation_sent", rel.id)

    rel
  end

  def queue_notification(event, relationship_id)
    NotificationJob.perform_later(event, relationship_id)
  rescue => e
    Rails.logger.error "[CoachingRelationshipCreationService] Error queueing notification: #{e.message}"
  end
end
