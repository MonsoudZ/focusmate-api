# frozen_string_literal: true

class ListUpdateService < ApplicationService
  class UnauthorizedError < StandardError; end
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(list:, user:, attributes:)
    @list = list
    @user = user
    @attributes = attributes
  end

  def call!
    validate_authorization!
    perform_update
    @list
  end

  private

  def validate_authorization!
    unless @list.can_edit?(@user)
      raise UnauthorizedError, "You do not have permission to edit this list"
    end
  end

  def perform_update
    unless @list.update(@attributes)
      raise ValidationError.new("Validation failed", @list.errors.as_json)
    end
  end
end
