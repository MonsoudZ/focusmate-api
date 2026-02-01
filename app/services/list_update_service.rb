# frozen_string_literal: true

class ListUpdateService < ApplicationService
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
      raise ApplicationError::Forbidden.new("You do not have permission to edit this list", code: "list_update_forbidden")
    end
  end

  def perform_update
    unless @list.update(@attributes)
      raise ApplicationError::Validation.new("Validation failed", details: @list.errors.as_json)
    end
  end
end
