# frozen_string_literal: true

class ListSharingService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end
  class NotFoundError < StandardError; end

  def initialize(list:, user:)
    @list = list
    @user = user
  end

  def share!(user_id: nil, email: nil, permissions: {})
    validate_authorization!
    validate_share_params!(user_id, email)

    target_user = find_target_user(user_id, email)
    create_or_update_share(target_user, permissions)
  end

  def unshare!(user_id:)
    validate_authorization!
    validate_unshare_params!(user_id)

    remove_share(user_id)
  end

  private

  def validate_authorization!
    unless @list.user_id == @user.id
      raise UnauthorizedError, "Only list owner can manage sharing"
    end
  end

  def validate_share_params!(user_id, email)
    if user_id.blank? && email.blank?
      raise ValidationError.new("Validation failed", { email: ["is required"] })
    end
  end

  def validate_unshare_params!(user_id)
    if user_id.blank?
      raise ValidationError.new("Validation failed", { user_id: ["is required"] })
    end
  end

  def find_target_user(user_id, email)
    if email.present?
      normalized_email = email.to_s.downcase.strip
      user = User.find_by('LOWER(email) = ?', normalized_email)
      unless user
        raise ValidationError.new("Validation failed", { email: ["User not found"] })
      end
      user
    else
      User.find(user_id)
    end
  rescue ActiveRecord::RecordNotFound
    raise NotFoundError, "User not found"
  end

  def create_or_update_share(target_user, permissions)
    share = ListShare.find_or_initialize_by(list_id: @list.id, email: target_user.email)
    share.user_id = target_user.id
    share.status = :accepted
    share.can_view = cast_boolean(permissions.fetch(:can_view, true))
    share.can_edit = cast_boolean(permissions.fetch(:can_edit, false))
    share.can_add_items = cast_boolean(permissions.fetch(:can_add_items, false))
    share.can_delete_items = cast_boolean(permissions.fetch(:can_delete_items, false))
    share.receive_notifications = cast_boolean(permissions.fetch(:receive_notifications, true))

    unless share.save
      raise ValidationError.new("Validation failed", share.errors.as_json)
    end

    share
  end

  def remove_share(user_id)
    share = ListShare.find_by(list_id: @list.id, user_id: user_id)
    share&.destroy!
    true
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
