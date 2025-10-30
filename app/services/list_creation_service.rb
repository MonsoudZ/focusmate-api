# frozen_string_literal: true

class ListCreationService
  class ValidationError < StandardError
    attr_reader :details
    def initialize(message, details = {})
      super(message)
      @details = details
    end
  end

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def create!
    validate_params!
    build_list
    save_list!
    @list
  end

  private

  def validate_params!
    # Check if params are blank and no name is provided
    cleaned = @params.except(:controller, :action, :list).to_h
    if cleaned.blank? && !@params.key?(:name)
      raise ValidationError.new("Validation failed", ["Name can't be blank"])
    end
  end

  def build_list
    @list = @user.owned_lists.new(@params)
    @list.visibility ||= "private" # Set default visibility
  end

  def save_list!
    unless @list.save
      raise ValidationError.new("Validation failed", @list.errors.as_json)
    end
  end
end
