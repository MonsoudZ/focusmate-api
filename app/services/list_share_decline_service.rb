# frozen_string_literal: true

class ListShareDeclineService
  class ValidationError < StandardError; end

  def initialize(list_share:)
    @list_share = list_share
  end

  def decline!
    validate_pending!
    @list_share.decline!
    true
  end

  private

  def validate_pending!
    unless @list_share.pending?
      raise ValidationError, "Invitation is not pending"
    end
  end
end
