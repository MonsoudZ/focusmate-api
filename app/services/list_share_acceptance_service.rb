# frozen_string_literal: true

class ListShareAcceptanceService
  class ValidationError < StandardError; end
  class NotFoundError < StandardError; end

  def initialize(list_share:, current_user: nil)
    @list_share = list_share
    @current_user = current_user
  end

  def accept!(invitation_token: nil)
    validate_token!(invitation_token) if invitation_token.present?
    validate_pending!

    @list_share.accept!(@current_user)
    @list_share.reload
    @list_share
  end

  def self.accept_by_token!(token:)
    validate_token_presence!(token)

    list_share = ListShare.find_by(invitation_token: token, status: "pending")
    raise NotFoundError, "Invalid or expired invitation token" unless list_share

    user = User.find_by(email: list_share.email)
    raise NotFoundError, "User not found. Please register first." unless user

    list_share.update!(
      user_id: user.id,
      status: "accepted",
      accepted_at: Time.current,
      invitation_token: nil
    )

    list_share
  end

  private

  def validate_token!(given_token)
    expected = @list_share.invitation_token.to_s

    if given_token.to_s.blank? || given_token.to_s != expected
      raise ValidationError, "Invitation is not pending"
    end
  end

  def validate_pending!
    if @list_share.invitation_token.blank? || !@list_share.pending?
      raise ValidationError, "Invitation is not pending"
    end
  end

  def self.validate_token_presence!(token)
    if token.blank?
      raise ValidationError, "Token is required"
    end
  end
end
