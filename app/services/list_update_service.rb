# frozen_string_literal: true

class ListUpdateService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(list:, user:)
    @list = list
    @user = user
  end

  def update!(attributes:)
    validate_authorization!
    perform_update(attributes)
    @list
  end

  private

  def validate_authorization!
    unless @list.can_edit?(@user)
      raise UnauthorizedError, "You do not have permission to edit this list"
    end
  end

  def perform_update(attributes)
    unless @list.update(attributes)
      raise ValidationError.new("Validation failed", @list.errors.as_json)
    end
  end
end
