# frozen_string_literal: true

class ListShareCreationService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end
  class BadRequestError < StandardError; end

  def initialize(list:, current_user:)
    @list = list
    @current_user = current_user
  end

  def create!(email:, role: nil, permissions: {})
    validate_authorization!
    validate_email!(email)

    normalized_email = email.to_s.downcase.strip
    normalized_role = role.presence || "viewer"

    validate_role!(normalized_role)

    # If already shared, return the existing share
    if (existing_share = @list.list_shares.find_by(email: normalized_email))
      return { share: existing_share, created: false }
    end

    invited_user = User.find_by(email: normalized_email)

    list_share = if invited_user
      # Existing user -> create accepted/pending based on model logic
      @list.share_with!(invited_user, permissions.merge(role: normalized_role))
    else
      # Non-existent user -> pending invite
      @list.invite_by_email!(normalized_email, normalized_role, permissions)
    end

    unless list_share.persisted?
      raise ValidationError.new("Validation failed", list_share.errors.as_json)
    end

    { share: list_share, created: true }
  end

  private

  def validate_authorization!
    unless @list.user == @current_user
      raise ValidationError.new("Unauthorized", { base: ["Only list owner can manage shares"] })
    end
  end

  def validate_email!(email)
    if email.to_s.strip.blank?
      raise BadRequestError, "Email is required"
    end
  end

  def validate_role!(role)
    unless %w[viewer editor admin].include?(role)
      raise ValidationError.new("Validation failed", { role: ["Invalid role"] })
    end
  end
end
